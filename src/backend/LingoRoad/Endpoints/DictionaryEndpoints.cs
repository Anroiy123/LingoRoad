using LingoRoad.Services;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace LingoRoad.Endpoints;

public record DictionaryLookupRequest(string Word);

public static class DictionaryEndpoints
{
    public static void MapDictionary(this WebApplication app)
    {
        var g = app.MapGroup("/dictionary").RequireAuthorization();

        g.MapPost("/lookup", async (DictionaryLookupRequest req, IMlClient ml) =>
        {
            if (string.IsNullOrWhiteSpace(req.Word) || req.Word.Trim().Length > 100)
                return Results.BadRequest(new { error = "invalid_word" });

            var question = $"Định nghĩa ngắn gọn và 1 ví dụ của từ: {req.Word.Trim()}";
            
            try
            {
                var res = await ml.AdvisorAsync(new AdvisorRequest(question, new List<AdvisorSkillContext>(), "vi"));
                return Results.Ok(new { definition = res.Answer });
            }
            catch (MlInputRejectedException error) { return ApiResults.MlRejected(error); }
            catch (MlServiceUnavailableException) { return ApiResults.MlUnavailable(); }
        }).RequireRateLimiting("ml-upload");
    }
}
