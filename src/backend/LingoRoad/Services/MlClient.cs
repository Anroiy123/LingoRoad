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

public interface IMlClient
{
    Task<CatSelectResponse> CatSelectAsync(CatSelectRequest req, CancellationToken ct = default);
    Task<AdvisorResponse> AdvisorAsync(AdvisorRequest req, CancellationToken ct = default);
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
