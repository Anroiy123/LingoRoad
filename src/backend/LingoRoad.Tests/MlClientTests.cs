using System.Net;
using System.Text;
using LingoRoad.Services;

namespace LingoRoad.Tests;

public class MlClientTests
{
    private sealed class StubHandler(Func<HttpRequestMessage, HttpResponseMessage> respond) : HttpMessageHandler
    {
        public string? LastBody;
        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage req, CancellationToken ct)
        {
            LastBody = req.Content is null ? null : await req.Content.ReadAsStringAsync(ct);
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
        var client = new MlClient(new HttpClient(handler) { BaseAddress = new Uri("http://ml") });

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
        var client = new MlClient(new HttpClient(handler) { BaseAddress = new Uri("http://ml") });
        await Assert.ThrowsAsync<MlServiceUnavailableException>(() =>
            client.CatSelectAsync(new CatSelectRequest([], [])));
    }
}
