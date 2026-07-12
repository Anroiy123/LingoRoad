using Microsoft.EntityFrameworkCore;
using LingoRoad.Data;
using LingoRoad.Domain;
using LingoRoad.Services;

namespace LingoRoad.Endpoints;

public record CreateCardRequest(string SkillCode, string Front, string Back);
public record GradeRequest(int Rating);

public static class ReviewEndpoints
{
    public static void MapReviews(this WebApplication app)
    {
        var g = app.MapGroup("/reviews").RequireAuthorization();

        g.MapPost("/cards", async (CreateCardRequest req,
            System.Security.Claims.ClaimsPrincipal user, AppDbContext db) =>
        {
            var skill = await db.Skills.SingleOrDefaultAsync(s => s.Code == req.SkillCode);
            if (skill is null) return Results.BadRequest(new { error = "unknown_skill" });
            var card = new ReviewCard { UserId = user.UserId(), SkillId = skill.Id,
                Front = req.Front, Back = req.Back };
            db.ReviewCards.Add(card);
            await db.SaveChangesAsync();
            return Results.Created($"/reviews/{card.Id}",
                new { card.Id, card.Front, card.Back, card.Due, card.State });
        });

        g.MapGet("/due", async (System.Security.Claims.ClaimsPrincipal user, AppDbContext db) =>
            await db.ReviewCards
                .Where(c => c.UserId == user.UserId() && c.Due <= DateTime.UtcNow)
                .OrderBy(c => c.Due)
                .Select(c => new { c.Id, c.Front, c.Back, c.Due, c.State })
                .ToListAsync());

        g.MapPost("/{cardId:guid}/grade", async (Guid cardId, GradeRequest req,
            System.Security.Claims.ClaimsPrincipal user, AppDbContext db) =>
        {
            if (req.Rating is < 1 or > 4) return Results.BadRequest(new { error = "rating_1_to_4" });
            var card = await db.ReviewCards.SingleOrDefaultAsync(
                c => c.Id == cardId && c.UserId == user.UserId());
            if (card is null) return Results.NotFound();
            Fsrs.Review(card, (Grade)req.Rating, DateTime.UtcNow);
            await db.SaveChangesAsync();
            return Results.Ok(new { card.Id, card.Due, card.State,
                stability = card.Stability, difficulty = card.Difficulty });
        });
    }
}
