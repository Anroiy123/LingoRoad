using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace LingoRoad.Services;

public class MlServiceUnavailableException(Exception inner)
    : Exception("ML service unavailable", inner);

public class MlInputRejectedException(int statusCode, string error)
    : Exception(error)
{
    public int StatusCode { get; } = statusCode;
    public string Error { get; } = error;
}

public sealed class MlCircuitBreaker
{
    private const int FailureThreshold = 3;
    private static readonly TimeSpan BreakDuration = TimeSpan.FromSeconds(30);
    private readonly object _sync = new();
    private int _consecutiveFailures;
    private DateTimeOffset _openUntil;

    public void ThrowIfOpen()
    {
        lock (_sync)
        {
            if (_openUntil > DateTimeOffset.UtcNow)
                throw new MlServiceUnavailableException(
                    new InvalidOperationException("ML circuit breaker is open."));
            if (_openUntil != default)
            {
                _openUntil = default;
                _consecutiveFailures = 0;
            }
        }
    }

    public void RecordSuccess()
    {
        lock (_sync)
        {
            _consecutiveFailures = 0;
            _openUntil = default;
        }
    }

    public void RecordFailure()
    {
        lock (_sync)
        {
            _consecutiveFailures++;
            if (_consecutiveFailures >= FailureThreshold)
                _openUntil = DateTimeOffset.UtcNow.Add(BreakDuration);
        }
    }
}

public record CatHistory(double A, double B, double C, bool Correct);
public record CatCandidate([property: JsonPropertyName("item_id")] Guid ItemId,
    double A, double B, double C);
public record CatSelectRequest(List<CatHistory> History, List<CatCandidate> Candidates);
public record CatSelectResponse(double Theta, double Se,
    [property: JsonPropertyName("next_item_id")] Guid? NextItemId);

public record AdvisorSkillContext(string Code, string Name, double Mastery, string Reason);
public record AdvisorRequest(string Question, List<AdvisorSkillContext> Path, string Locale);
public record AdvisorResponse(string Answer);

public record ExerciseGenRequest(string SkillCode, string SkillName, string Cefr, string Type, int Count);
public record GeneratedExercise(string Stem, string[] Options, string CorrectAnswer, string? ExplanationVi);
public record ExerciseGenResponse(List<GeneratedExercise> Exercises,
    [property: JsonPropertyName("model_version")] string? ModelVersion = null);

public record AweRequest(string TaskPrompt, string Essay);
public record AweScores(double TaskAchievement, double CoherenceCohesion, double LexicalResource, double GrammaticalAccuracy);
public record AweFeedback(string Sentence, string Issue, string Suggestion);
public record AweResponse(AweScores Scores, List<AweFeedback> Feedback, string OverallVi);

public record SpeakingScoreResponse(string Transcript, double Accuracy, double Completeness,
    double Fluency, double Total, double DurationSeconds,
    [property: JsonPropertyName("model_version")] string ModelVersion,
    [property: JsonPropertyName("feedback_vi")] string FeedbackVi);

public interface IMlClient
{
    Task<CatSelectResponse> CatSelectAsync(CatSelectRequest req, CancellationToken ct = default);
    Task<AdvisorResponse> AdvisorAsync(AdvisorRequest req, CancellationToken ct = default);
    Task<ExerciseGenResponse> GenerateExercisesAsync(ExerciseGenRequest req, CancellationToken ct = default);
    Task<AweResponse> EvaluateWritingAsync(AweRequest req, CancellationToken ct = default);
    Task<SpeakingScoreResponse> ScoreSpeakingAsync(Stream audio, string fileName, string promptText, CancellationToken ct = default);
}

public class MlClient(HttpClient http, MlCircuitBreaker circuitBreaker) : IMlClient
{
    private const int MaxAttempts = 2;
    private static readonly TimeSpan DefaultTimeout = TimeSpan.FromSeconds(30);
    private static readonly TimeSpan SpeechTimeout = TimeSpan.FromSeconds(90);
    public static readonly JsonSerializerOptions Json = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
        PropertyNameCaseInsensitive = true
    };

    public async Task<CatSelectResponse> CatSelectAsync(CatSelectRequest req, CancellationToken ct = default)
        => await PostAsync<CatSelectRequest, CatSelectResponse>("/cat/select", req, ct);

    public async Task<AdvisorResponse> AdvisorAsync(AdvisorRequest req, CancellationToken ct = default)
        => await PostAsync<AdvisorRequest, AdvisorResponse>("/llm/advisor", req, ct);

    public async Task<ExerciseGenResponse> GenerateExercisesAsync(ExerciseGenRequest req, CancellationToken ct = default)
        => await PostAsync<ExerciseGenRequest, ExerciseGenResponse>("/llm/exercises", req, ct);

    public async Task<AweResponse> EvaluateWritingAsync(AweRequest req, CancellationToken ct = default)
        => await PostAsync<AweRequest, AweResponse>("/llm/awe", req, ct);

    public async Task<SpeakingScoreResponse> ScoreSpeakingAsync(Stream audio, string fileName,
        string promptText, CancellationToken ct = default)
    {
        var initialPosition = audio.CanSeek ? audio.Position : 0;
        var contentType = Path.GetExtension(fileName).ToLowerInvariant() switch
        {
            ".webm" => "audio/webm",
            ".mp3" => "audio/mpeg",
            ".wav" => "audio/wav",
            ".m4a" => "audio/mp4",
            ".ogg" => "audio/ogg",
            _ => "application/octet-stream"
        };

        return await SendAsync<SpeakingScoreResponse>(() =>
        {
            if (audio.CanSeek) audio.Position = initialPosition;
            var streamContent = new NonDisposingStreamContent(audio);
            streamContent.Headers.ContentType = new MediaTypeHeaderValue(contentType);
            var form = new MultipartFormDataContent
            {
                { streamContent, "file", fileName },
                { new StringContent(promptText), "prompt_text" }
            };
            return new HttpRequestMessage(HttpMethod.Post, "/speech/score") { Content = form };
        }, SpeechTimeout, ct, retryable: audio.CanSeek);
    }

    protected Task<TRes> PostAsync<TReq, TRes>(string path, TReq body, CancellationToken ct)
        => SendAsync<TRes>(() => new HttpRequestMessage(HttpMethod.Post, path)
        {
            Content = JsonContent.Create(body, options: Json)
        }, DefaultTimeout, ct, retryable: true);

    private async Task<TRes> SendAsync<TRes>(Func<HttpRequestMessage> requestFactory,
        TimeSpan timeout, CancellationToken ct, bool retryable)
    {
        circuitBreaker.ThrowIfOpen();
        Exception? lastError = null;
        var attempts = retryable ? MaxAttempts : 1;

        for (var attempt = 1; attempt <= attempts; attempt++)
        {
            try
            {
                using var request = requestFactory();
                using var timeoutCts = CancellationTokenSource.CreateLinkedTokenSource(ct);
                timeoutCts.CancelAfter(timeout);
                using var response = await http.SendAsync(request,
                    HttpCompletionOption.ResponseHeadersRead, timeoutCts.Token);
                if (IsInputRejection(response.StatusCode))
                    throw new MlInputRejectedException((int)response.StatusCode,
                        await ReadErrorAsync(response, ct));
                if (IsTransient(response.StatusCode))
                {
                    lastError = new HttpRequestException(
                        $"ML service returned {(int)response.StatusCode}.", null,
                        response.StatusCode);
                    if (attempt < attempts) continue;
                    break;
                }

                if (!response.IsSuccessStatusCode)
                {
                    lastError = new HttpRequestException(
                        $"ML service returned {(int)response.StatusCode}.", null,
                        response.StatusCode);
                    break;
                }

                var value = await response.Content.ReadFromJsonAsync<TRes>(Json, ct);
                if (value is null) throw new JsonException("ML service returned an empty body.");
                circuitBreaker.RecordSuccess();
                return value;
            }
            catch (MlInputRejectedException)
            {
                throw;
            }
            catch (OperationCanceledException) when (ct.IsCancellationRequested)
            {
                throw;
            }
            catch (Exception error) when (error is HttpRequestException or
                TaskCanceledException or JsonException)
            {
                lastError = error;
                if (attempt < attempts) continue;
            }
        }

        circuitBreaker.RecordFailure();
        throw new MlServiceUnavailableException(lastError ??
            new HttpRequestException("ML service request failed."));
    }

    private static bool IsTransient(HttpStatusCode status) =>
        status is HttpStatusCode.RequestTimeout or HttpStatusCode.TooManyRequests ||
        (int)status >= 500;

    private static bool IsInputRejection(HttpStatusCode status) =>
        status is HttpStatusCode.BadRequest or HttpStatusCode.RequestEntityTooLarge or
            HttpStatusCode.UnsupportedMediaType or HttpStatusCode.UnprocessableEntity;

    private static async Task<string> ReadErrorAsync(HttpResponseMessage response,
        CancellationToken ct)
    {
        try
        {
            using var body = await JsonDocument.ParseAsync(
                await response.Content.ReadAsStreamAsync(ct), cancellationToken: ct);
            if (body.RootElement.TryGetProperty("error", out var error))
                return error.GetString() ?? "ml_input_rejected";
            if (body.RootElement.TryGetProperty("detail", out var detail))
                return detail.ValueKind == JsonValueKind.String
                    ? detail.GetString() ?? "ml_input_rejected"
                    : "ml_input_rejected";
        }
        catch (JsonException)
        {
            // Fall back to a stable public error code.
        }
        return "ml_input_rejected";
    }

    private sealed class NonDisposingStreamContent(Stream stream) : HttpContent
    {
        protected override Task SerializeToStreamAsync(Stream target,
            TransportContext? context) => stream.CopyToAsync(target);

        protected override bool TryComputeLength(out long length)
        {
            if (!stream.CanSeek)
            {
                length = 0;
                return false;
            }
            length = stream.Length - stream.Position;
            return true;
        }
    }
}
