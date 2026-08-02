using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using LingoRoad.Data;
using LingoRoad.Domain;
using LingoRoad.Services;

namespace LingoRoad.Endpoints;

public record PlacementItemDto(Guid Id, string Type, string Stem, string[] Options, string? AudioUrl);
public record AnswerRequest(Guid ItemId, string? Answer);

public static class PlacementEndpoints
{
    private const int MinItems = 8, MaxItems = 30;
    private const double SeThreshold = 0.35;

    // Placement uses the choice-only client. Cloze and reorder items stay in
    // lessons, whose player supports their distinct interaction models.
    private static readonly string[] PlacementItemTypes = ["mcq", "listening_mcq"];

    private static PlacementItemDto ToDto(Item i) => new(
        i.Id, i.Type, i.Stem, JsonSerializer.Deserialize<string[]>(i.OptionsJson)!, i.AudioUrl);

    private static async Task<(double theta, double se, Item? next)> AskMlAsync(
        AppDbContext db, IMlClient ml, Guid sessionId,
        Item? pendingItem = null, bool? pendingCorrect = null)
    {
        var answered = await db.Responses
            .Where(r => r.SessionId == sessionId)
            .Join(db.Items, r => r.ItemId, i => i.Id,
                  (r, i) => new { i.A, i.B, i.C, r.Correct, i.Id })
            .ToListAsync();
        var answeredIds = answered.Select(x => x.Id).ToHashSet();
        var history = answered
            .Select(x => new CatHistory(x.A, x.B, x.C, x.Correct))
            .ToList();
        if (pendingItem is not null && pendingCorrect is not null)
        {
            answeredIds.Add(pendingItem.Id);
            history.Add(new CatHistory(
                pendingItem.A, pendingItem.B, pendingItem.C, pendingCorrect.Value));
        }
        var candidates = await db.Items
            .Where(i => !answeredIds.Contains(i.Id) && !i.IsDeleted &&
                PlacementItemTypes.Contains(i.Type))
            .ToListAsync();

        var res = await ml.CatSelectAsync(new CatSelectRequest(
            history,
            candidates.Select(i => new CatCandidate(i.Id, i.A, i.B, i.C)).ToList()));

        return (res.Theta, res.Se, candidates.FirstOrDefault(i => i.Id == res.NextItemId));
    }

    private static bool AnswersMatch(string? stored, string? received) =>
        string.Equals(stored?.Trim(), received?.Trim(), StringComparison.OrdinalIgnoreCase);

    private static async Task<IResult> ToAnswerResultAsync(AppDbContext db, Response response)
    {
        if (response.CompletedAfter)
            return Results.Ok(new
            {
                done = true,
                theta = response.ThetaAfter,
                se = response.SeAfter,
                cefr = response.ResultCefrAfter
            });

        if (response.NextItemId is not Guid nextItemId)
            return Results.Conflict(new { error = "placement_state_invalid" });

        var next = await db.Items.FindAsync(nextItemId);
        return next is null
            ? Results.Conflict(new { error = "placement_state_invalid" })
            : Results.Ok(new { done = false, item = ToDto(next) });
    }

    public static void MapPlacement(this WebApplication app)
    {
        var g = app.MapGroup("/placement").RequireAuthorization();

        g.MapGet("/status", async (System.Security.Claims.ClaimsPrincipal user,
            AppDbContext db) =>
        {
            var completed = await db.TestSessions.AnyAsync(
                s => s.UserId == user.UserId() && s.Status == "completed");
            return Results.Ok(new { completed });
        });

        g.MapPost("/start", async (System.Security.Claims.ClaimsPrincipal user,
            AppDbContext db, IMlClient ml) =>
        {
            var session = new TestSession { UserId = user.UserId() };
            try
            {
                var (theta, se, next) = await AskMlAsync(db, ml, session.Id);
                if (next is null) return Results.Conflict(new { error = "empty_item_bank" });
                session.CurrentItemId = next.Id;
                db.TestSessions.Add(session);
                await db.SaveChangesAsync();
                return Results.Ok(new { sessionId = session.Id, item = ToDto(next) });
            }
            catch (MlServiceUnavailableException) { return ApiResults.MlUnavailable(); }
        });

        g.MapPost("/{sessionId:guid}/answer", async (Guid sessionId, AnswerRequest req,
            System.Security.Claims.ClaimsPrincipal user, AppDbContext db, IMlClient ml,
            MasteryService masteries) =>
        {
            if (req.ItemId == Guid.Empty)
                return Results.BadRequest(new { error = "item_id_required" });
            if (string.IsNullOrWhiteSpace(req.Answer))
                return Results.BadRequest(new { error = "answer_required" });

            var session = await db.TestSessions.SingleOrDefaultAsync(
                s => s.Id == sessionId && s.UserId == user.UserId());
            if (session is null) return Results.NotFound();

            var existing = await db.Responses.SingleOrDefaultAsync(
                r => r.SessionId == sessionId && r.ItemId == req.ItemId);
            if (existing is not null)
            {
                if (!AnswersMatch(existing.Answer, req.Answer))
                    return Results.Conflict(new { error = "answer_already_recorded" });
                return await ToAnswerResultAsync(db, existing);
            }

            if (session.Status != "active")
                return Results.Conflict(new { error = "session_completed" });
            if (session.CurrentItemId != req.ItemId)
                return Results.Conflict(new { error = "item_not_issued" });

            var item = await db.Items.SingleOrDefaultAsync(i => i.Id == req.ItemId);
            if (item is null)
                return Results.Conflict(new { error = "placement_state_invalid" });

            var correct = string.Equals(req.Answer.Trim(), item.CorrectAnswer.Trim(),
                StringComparison.OrdinalIgnoreCase);
            try
            {
                var (theta, se, next) = await AskMlAsync(
                    db, ml, sessionId, item, correct);
                var count = await db.Responses.CountAsync(r => r.SessionId == sessionId) + 1;
                var stop = count >= MaxItems ||
                    (count >= MinItems && se < SeThreshold) ||
                    next is null;

                var response = new Response { SessionId = sessionId, ItemId = item.Id,
                    Answer = req.Answer, Correct = correct, ThetaAfter = theta, SeAfter = se,
                    NextItemId = stop ? null : next!.Id, CompletedAfter = stop,
                    ResultCefrAfter = stop ? CefrMap.FromTheta(theta) : null };
                db.Responses.Add(response);
                await masteries.RecordAnswerAsync(
                    user.UserId(), item.SkillId, correct, saveChanges: false);
                session.Theta = theta; session.ThetaSe = se;
                session.CurrentItemId = stop ? null : next!.Id;

                if (stop)
                {
                    session.Status = "completed";
                    session.CompletedAt = DateTime.UtcNow;
                    session.ResultCefr = response.ResultCefrAfter;
                }

                await db.SaveChangesAsync();
                return await ToAnswerResultAsync(db, response);
            }
            catch (MlServiceUnavailableException) { return ApiResults.MlUnavailable(); }
            catch (DbUpdateException)
            {
                db.ChangeTracker.Clear();
                var replay = await db.Responses.SingleOrDefaultAsync(
                    r => r.SessionId == sessionId && r.ItemId == req.ItemId);
                if (replay is null) throw;
                if (!AnswersMatch(replay.Answer, req.Answer))
                    return Results.Conflict(new { error = "answer_already_recorded" });
                return await ToAnswerResultAsync(db, replay);
            }
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
