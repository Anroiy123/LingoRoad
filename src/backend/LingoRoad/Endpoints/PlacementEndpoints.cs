using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using LingoRoad.Data;
using LingoRoad.Domain;
using LingoRoad.Services;

namespace LingoRoad.Endpoints;

public record PlacementItemDto(Guid Id, string Type, string Stem, string[] Options, string? AudioUrl);
public record AnswerRequest(Guid ItemId, string Answer);

public static class PlacementEndpoints
{
    private const int MinItems = 8, MaxItems = 30;
    private const double SeThreshold = 0.35;

    private static PlacementItemDto ToDto(Item i) => new(
        i.Id, i.Type, i.Stem, JsonSerializer.Deserialize<string[]>(i.OptionsJson)!, i.AudioUrl);

    private static async Task<(double theta, double se, Item? next)> AskMlAsync(
        AppDbContext db, IMlClient ml, Guid sessionId)
    {
        var answered = await db.Responses
            .Where(r => r.SessionId == sessionId)
            .Join(db.Items, r => r.ItemId, i => i.Id,
                  (r, i) => new { i.A, i.B, i.C, r.Correct, i.Id })
            .ToListAsync();
        var answeredIds = answered.Select(x => x.Id).ToHashSet();
        var candidates = await db.Items.Where(i => !answeredIds.Contains(i.Id)).ToListAsync();

        var res = await ml.CatSelectAsync(new CatSelectRequest(
            answered.Select(x => new CatHistory(x.A, x.B, x.C, x.Correct)).ToList(),
            candidates.Select(i => new CatCandidate(i.Id, i.A, i.B, i.C)).ToList()));

        return (res.Theta, res.Se, candidates.FirstOrDefault(i => i.Id == res.NextItemId));
    }

    public static void MapPlacement(this WebApplication app)
    {
        var g = app.MapGroup("/placement").RequireAuthorization();

        g.MapPost("/start", async (System.Security.Claims.ClaimsPrincipal user,
            AppDbContext db, IMlClient ml) =>
        {
            var session = new TestSession { UserId = user.UserId() };
            db.TestSessions.Add(session);
            await db.SaveChangesAsync();
            try
            {
                var (theta, se, next) = await AskMlAsync(db, ml, session.Id);
                if (next is null) return Results.Conflict(new { error = "empty_item_bank" });
                return Results.Ok(new { sessionId = session.Id, item = ToDto(next) });
            }
            catch (MlServiceUnavailableException) { return ApiResults.MlUnavailable(); }
        });

        g.MapPost("/{sessionId:guid}/answer", async (Guid sessionId, AnswerRequest req,
            System.Security.Claims.ClaimsPrincipal user, AppDbContext db, IMlClient ml,
            MasteryService masteries) =>
        {
            var session = await db.TestSessions.SingleOrDefaultAsync(
                s => s.Id == sessionId && s.UserId == user.UserId());
            if (session is null) return Results.NotFound();
            if (session.Status != "active") return Results.Conflict(new { error = "session_completed" });

            var item = await db.Items.FindAsync(req.ItemId);
            if (item is null) return Results.BadRequest(new { error = "unknown_item" });

            var correct = string.Equals(req.Answer.Trim(), item.CorrectAnswer.Trim(),
                StringComparison.OrdinalIgnoreCase);
            try
            {
                var response = new Response { SessionId = sessionId, ItemId = item.Id,
                    Answer = req.Answer, Correct = correct };
                db.Responses.Add(response);
                await db.SaveChangesAsync();
                await masteries.RecordAnswerAsync(user.UserId(), item.SkillId, correct);

                var (theta, se, next) = await AskMlAsync(db, ml, sessionId);
                var count = await db.Responses.CountAsync(r => r.SessionId == sessionId);
                response.ThetaAfter = theta; response.SeAfter = se;
                session.Theta = theta; session.ThetaSe = se;

                var stop = count >= MaxItems || (count >= MinItems && se < SeThreshold) || next is null;
                if (stop)
                {
                    session.Status = "completed";
                    session.CompletedAt = DateTime.UtcNow;
                    session.ResultCefr = CefrMap.FromTheta(theta);
                    await db.SaveChangesAsync();
                    return Results.Ok(new { done = true, theta, se, cefr = session.ResultCefr });
                }
                await db.SaveChangesAsync();
                return Results.Ok(new { done = false, item = ToDto(next!) });
            }
            catch (MlServiceUnavailableException) { return ApiResults.MlUnavailable(); }
        });

        g.MapGet("/{sessionId:guid}/result", async (Guid sessionId,
            System.Security.Claims.ClaimsPrincipal user, AppDbContext db) =>
        {
            var session = await db.TestSessions.SingleOrDefaultAsync(
                s => s.Id == sessionId && s.UserId == user.UserId());
            if (session is null) return Results.NotFound();
            var n = await db.Responses.CountAsync(r => r.SessionId == sessionId);
            return Results.Ok(new { theta = session.Theta, se = session.ThetaSe,
                cefr = session.ResultCefr ?? CefrMap.FromTheta(session.Theta),
                itemsAnswered = n, status = session.Status });
        });
    }
}
