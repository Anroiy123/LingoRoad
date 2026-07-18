using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace LingoRoad.Services;

public class MlServiceUnavailableException(Exception inner)
    : Exception("ML service unavailable", inner);

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
public record ExerciseGenResponse(List<GeneratedExercise> Exercises);

public record AweRequest(string TaskPrompt, string Essay);
public record AweScores(double TaskAchievement, double CoherenceCohesion, double LexicalResource, double GrammaticalAccuracy);
public record AweFeedback(string Sentence, string Issue, string Suggestion);
public record AweResponse(AweScores Scores, List<AweFeedback> Feedback, string OverallVi);

public interface IMlClient
{
    Task<CatSelectResponse> CatSelectAsync(CatSelectRequest req, CancellationToken ct = default);
    Task<AdvisorResponse> AdvisorAsync(AdvisorRequest req, CancellationToken ct = default);
    Task<ExerciseGenResponse> GenerateExercisesAsync(ExerciseGenRequest req, CancellationToken ct = default);
    Task<AweResponse> EvaluateWritingAsync(AweRequest req, CancellationToken ct = default);
}

public class MlClient(HttpClient http) : IMlClient
{
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

    protected async Task<TRes> PostAsync<TReq, TRes>(string path, TReq body, CancellationToken ct)
    {
        try
        {
            var res = await http.PostAsJsonAsync(path, body, Json, ct);
            res.EnsureSuccessStatusCode();
            return (await res.Content.ReadFromJsonAsync<TRes>(Json, ct))!;
        }
        catch (Exception e) when (e is HttpRequestException or TaskCanceledException)
        {
            throw new MlServiceUnavailableException(e);
        }
    }
}
