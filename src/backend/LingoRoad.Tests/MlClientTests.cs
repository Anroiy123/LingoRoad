using System.Net;
using System.Text;
using LingoRoad.Services;

namespace LingoRoad.Tests;

public class MlClientTests
{
    private sealed class StubHandler(Func<HttpRequestMessage, HttpResponseMessage> respond) : HttpMessageHandler
    {
        public string? LastBody;
        public string? LastContentType;
        public int Calls;
        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage req, CancellationToken ct)
        {
            Calls++;
            LastBody = req.Content is null ? null : await req.Content.ReadAsStringAsync(ct);
            LastContentType = req.Content?.Headers.ContentType?.ToString();
            return respond(req);
        }
    }

    [Fact]
    public async Task CatSelect_serializes_snake_case_and_parses_response()
    {
        var handler = new StubHandler(_ => new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = new StringContent(
                """{"theta":0.42,"se":0.31,"next_item_id":"11111111-1111-1111-1111-111111111111"}""",
                Encoding.UTF8, "application/json")
        });
        var client = CreateClient(handler);

        var res = await client.CatSelectAsync(new CatSelectRequest(
            [new CatHistory(1.0, 0.0, 0.25, true)],
            [new CatCandidate(Guid.NewGuid(), 1.2, 0.3, 0.25)]));

        Assert.Equal(0.42, res.Theta, 3);
        Assert.Equal(Guid.Parse("11111111-1111-1111-1111-111111111111"), res.NextItemId);
        Assert.Contains("\"item_id\"", handler.LastBody);
        Assert.Contains("\"correct\":true", handler.LastBody);
    }

    [Fact]
    public async Task Unreachable_service_throws_MlServiceUnavailableException()
    {
        var handler = new StubHandler(_ => throw new HttpRequestException("boom"));
        var client = CreateClient(handler);
        await Assert.ThrowsAsync<MlServiceUnavailableException>(() =>
            client.CatSelectAsync(new CatSelectRequest([], [])));
        Assert.Equal(2, handler.Calls);
    }

    [Fact]
    public async Task Input_rejection_is_not_retried_or_hidden_as_unavailable()
    {
        var handler = new StubHandler(_ => new HttpResponseMessage(HttpStatusCode.UnsupportedMediaType)
        {
            Content = new StringContent("{\"detail\":\"unsupported_audio_type\"}",
                Encoding.UTF8, "application/json")
        });
        var error = await Assert.ThrowsAsync<MlInputRejectedException>(() =>
            CreateClient(handler).ScoreSpeakingAsync(
                new MemoryStream("RIFF....WAVE"u8.ToArray()), "sample.wav", "prompt"));
        Assert.Equal(415, error.StatusCode);
        Assert.Equal("unsupported_audio_type", error.Error);
        Assert.Equal(1, handler.Calls);
    }

    [Fact]
    public async Task Internal_auth_failure_is_hidden_as_service_unavailable()
    {
        var handler = new StubHandler(_ =>
            new HttpResponseMessage(HttpStatusCode.Unauthorized));

        await Assert.ThrowsAsync<MlServiceUnavailableException>(() =>
            CreateClient(handler).CatSelectAsync(new CatSelectRequest([], [])));

        Assert.Equal(1, handler.Calls);
    }

    [Fact]
    public async Task Speaking_sends_audio_mime_and_retries_seekable_stream()
    {
        var handler = new StubHandler(_ => new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = new StringContent("""
                {"transcript":"hello","accuracy":1,"completeness":1,"fluency":1,
                 "total":1,"duration_seconds":1,"model_version":"test-v1","feedback_vi":"Tốt"}
                """, Encoding.UTF8, "application/json")
        });
        var result = await CreateClient(handler).ScoreSpeakingAsync(
            new MemoryStream("RIFF....WAVE"u8.ToArray()), "sample.wav", "prompt");
        Assert.Equal("test-v1", result.ModelVersion);
        Assert.Contains("multipart/form-data", handler.LastContentType);
        Assert.Contains("Content-Type: audio/wav", handler.LastBody);
    }

    [Fact]
    public async Task Transient_response_is_retried_once()
    {
        var responses = 0;
        var handler = new StubHandler(_ => ++responses == 1
            ? new HttpResponseMessage(HttpStatusCode.ServiceUnavailable)
            : new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(
                    """{"theta":0.0,"se":1.0,"next_item_id":null}""",
                    Encoding.UTF8, "application/json")
            });

        var result = await CreateClient(handler)
            .CatSelectAsync(new CatSelectRequest([], []));

        Assert.Equal(2, handler.Calls);
        Assert.Null(result.NextItemId);
    }

    [Fact]
    public async Task Circuit_opens_after_three_failed_operations()
    {
        var handler = new StubHandler(_ => throw new HttpRequestException("down"));
        var client = new MlClient(
            new HttpClient(handler) { BaseAddress = new Uri("http://ml") },
            new MlCircuitBreaker());

        for (var index = 0; index < 3; index++)
            await Assert.ThrowsAsync<MlServiceUnavailableException>(() =>
                client.CatSelectAsync(new CatSelectRequest([], [])));
        await Assert.ThrowsAsync<MlServiceUnavailableException>(() =>
            client.CatSelectAsync(new CatSelectRequest([], [])));

        Assert.Equal(6, handler.Calls);
    }

    private static MlClient CreateClient(HttpMessageHandler handler) =>
        new(new HttpClient(handler) { BaseAddress = new Uri("http://ml") },
            new MlCircuitBreaker());
}
