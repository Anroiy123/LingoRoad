using System.Net;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using LingoRoad.Data;

namespace LingoRoad.Tests;

public class SpeakingTests : IClassFixture<PlacementFactory>
{
    private readonly PlacementFactory _factory;
    private readonly HttpClient _client;
    public SpeakingTests(PlacementFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task Valid_upload_stores_scores_without_audio_and_returns_history()
    {
        await AuthenticateAsync();
        var response = await UploadAsync("audio/webm", WebmBytes());
        response.EnsureSuccessStatusCode();
        var body = await response.Content.ReadAsStringAsync();
        Assert.Contains("whisper-small-test", body);
        Assert.Contains("durationSeconds", body);

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var attempt = await db.SpeakingAttempts.OrderByDescending(x => x.CreatedAt).FirstAsync();
            Assert.Equal("whisper-small-test", attempt.ModelVersion);
            Assert.Equal(3, attempt.DurationSeconds);
            Assert.DoesNotContain("AudioPath", attempt.ScoresJson ?? "", StringComparison.OrdinalIgnoreCase);
            var learningEvent = await db.LearningEvents.SingleAsync(e =>
                e.OperationId == attempt.Id && e.EventType == "speaking_scored");
            Assert.Equal("whisper-small-test", learningEvent.ModelVersion);
        }

        var history = await _client.GetFromJsonAsync<List<Dictionary<string, object>>>(
            "/speaking/attempts");
        Assert.Single(history!);
    }

    [Fact]
    public async Task Upload_rejects_declared_or_actual_mime_mismatch()
    {
        await AuthenticateAsync();
        Assert.Equal(HttpStatusCode.UnsupportedMediaType,
            (await UploadAsync("application/octet-stream", WebmBytes())).StatusCode);
        var mismatch = await UploadAsync("audio/webm", "not-webm"u8.ToArray());
        Assert.Equal(HttpStatusCode.UnsupportedMediaType, mismatch.StatusCode);
        Assert.Contains("audio_signature_mismatch", await mismatch.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task Upload_rejects_audio_over_duration_limit()
    {
        await AuthenticateAsync();
        _factory.Fake.SpeakingDurationSeconds = 121;
        try
        {
            var response = await UploadAsync("audio/webm", WebmBytes());
            Assert.Equal(HttpStatusCode.RequestEntityTooLarge, response.StatusCode);
            Assert.Contains("audio_too_long", await response.Content.ReadAsStringAsync());
        }
        finally
        {
            _factory.Fake.SpeakingDurationSeconds = 3;
        }
    }

    private async Task AuthenticateAsync()
    {
        var reg = await _client.PostAsJsonAsync("/auth/register",
            new { email = $"{Guid.NewGuid():N}@t.com", password = "secret123", name = "S" });
        var token = (await reg.Content.ReadFromJsonAsync<Dictionary<string, string>>())!["token"];
        _client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);
    }

    private async Task<HttpResponseMessage> UploadAsync(string contentType, byte[] bytes)
    {
        using var audio = new ByteArrayContent(bytes);
        audio.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue(contentType);
        using var form = new MultipartFormDataContent
        {
            { audio, "audio", "sample.webm" },
            { new StringContent("I have lived here for two years"), "promptText" }
        };
        return await _client.PostAsync("/speaking/attempts", form);
    }

    private static byte[] WebmBytes() =>
        [0x1A, 0x45, 0xDF, 0xA3, 0x42, 0x86, 0x81, 0x01];
}
