# Task 11: FSRS Spaced Repetition â€” scheduler + review queue

> Part of the QuestGraph plan. Read **Global Constraints** in `.claude/tasks/README.md` first.
> Depends on: task-2, task-3. Sprint 3. Pure C# â€” no ML service involved.

**Files:**
- Create: `QuestGraph/Domain/ReviewCard.cs`, `QuestGraph/Domain/Fsrs.cs`, `QuestGraph/Endpoints/ReviewEndpoints.cs`, `QuestGraph.Tests/FsrsTests.cs`
- Modify: `QuestGraph/Data/AppDbContext.cs`, `QuestGraph/Program.cs`

**Interfaces:**
- Consumes: auth, `Skill`.
- Produces: `ReviewCard { Guid Id, Guid UserId, int SkillId, string Front, string Back, double Stability, double Difficulty, DateTime Due, DateTime? LastReview, int Reps, string State }` (State âˆˆ `new|review|relearning`); `enum Grade { Again=1, Hard=2, Good=3, Easy=4 }`; `Fsrs.Review(card, grade, now)` mutating stability/difficulty/due/state; endpoints `POST /reviews/cards`, `GET /reviews/due`, `POST /reviews/{cardId}/grade`. Task-16's smoke script drives these.

**Algorithm:** FSRS-4.5 (reference implementation: py-fsrs) with default weights and target retention 0.9 â€” with that retention and FSRS-4.5's power forgetting curve `R(t,S) = (1 + 19/81 Â· t/S)^(-0.5)`, the next interval equals the stability `S` in days. `Again` sends the card to relearning, due in 10 minutes.

- [x] **Step 1: Write failing FSRS property tests**

`QuestGraph.Tests/FsrsTests.cs`:

```csharp
using QuestGraph.Domain;

namespace QuestGraph.Tests;

public class FsrsTests
{
    private static ReviewCard NewCard() => new()
        { UserId = Guid.NewGuid(), SkillId = 1, Front = "hi", Back = "chÃ o" };

    private static ReviewCard Reviewed(Grade g, DateTime now)
    {
        var c = NewCard();
        Fsrs.Review(c, g, now);
        return c;
    }

    [Fact]
    public void First_review_orders_intervals_by_grade()
    {
        var now = DateTime.UtcNow;
        var hard = Reviewed(Grade.Hard, now);
        var good = Reviewed(Grade.Good, now);
        var easy = Reviewed(Grade.Easy, now);
        Assert.True(easy.Due > good.Due);
        Assert.True(good.Due > hard.Due);
    }

    [Fact]
    public void Again_goes_to_relearning_within_minutes()
    {
        var now = DateTime.UtcNow;
        var c = Reviewed(Grade.Again, now);
        Assert.Equal("relearning", c.State);
        Assert.True(c.Due <= now.AddMinutes(15));
    }

    [Fact]
    public void Repeated_good_reviews_grow_stability()
    {
        var now = DateTime.UtcNow;
        var c = NewCard();
        Fsrs.Review(c, Grade.Good, now);
        var s1 = c.Stability;
        Fsrs.Review(c, Grade.Good, now.AddDays(c.Stability));
        var s2 = c.Stability;
        Fsrs.Review(c, Grade.Good, now.AddDays(c.Stability + s1));
        Assert.True(s2 > s1);
        Assert.True(c.Stability > s2);
    }

    [Fact]
    public void Difficulty_stays_in_1_to_10()
    {
        var now = DateTime.UtcNow;
        var c = NewCard();
        Fsrs.Review(c, Grade.Again, now);
        for (var i = 0; i < 20; i++) Fsrs.Review(c, Grade.Again, now = now.AddDays(1));
        Assert.InRange(c.Difficulty, 1.0, 10.0);
        for (var i = 0; i < 20; i++) Fsrs.Review(c, Grade.Easy, now = now.AddDays(1));
        Assert.InRange(c.Difficulty, 1.0, 10.0);
    }

    [Fact]
    public void Forgetting_reduces_stability()
    {
        var now = DateTime.UtcNow;
        var c = NewCard();
        Fsrs.Review(c, Grade.Good, now);
        Fsrs.Review(c, Grade.Good, now.AddDays(c.Stability));
        var before = c.Stability;
        Fsrs.Review(c, Grade.Again, now.AddDays(before * 2));
        Assert.True(c.Stability < before);
    }
}
```

Run: `dotnet test QuestGraph.Tests --filter FsrsTests` â†’ FAIL.

- [x] **Step 2: Implement FSRS, verify pass**

`QuestGraph/Domain/ReviewCard.cs`:

```csharp
namespace QuestGraph.Domain;

public enum Grade { Again = 1, Hard = 2, Good = 3, Easy = 4 }

public class ReviewCard
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public int SkillId { get; set; }
    public required string Front { get; set; }
    public required string Back { get; set; }
    public double Stability { get; set; }
    public double Difficulty { get; set; }
    public DateTime Due { get; set; } = DateTime.UtcNow;
    public DateTime? LastReview { get; set; }
    public int Reps { get; set; }
    public string State { get; set; } = "new";
}
```

`QuestGraph/Domain/Fsrs.cs`:

```csharp
namespace QuestGraph.Domain;

/// FSRS-4.5 scheduler, default weights, target retention 0.9 (interval == stability).
public static class Fsrs
{
    private static readonly double[] W =
    [
        0.4872, 1.4003, 3.7145, 13.8206, 5.1618, 1.2298, 0.8975, 0.031,
        1.6474, 0.1367, 1.0461, 2.1072, 0.0793, 0.3246, 1.587, 0.2272, 2.8755
    ];
    private const double Decay = -0.5;
    private const double Factor = 19.0 / 81.0;

    public static double Retrievability(double days, double stability) =>
        Math.Pow(1.0 + Factor * days / stability, Decay);

    private static double InitStability(Grade g) => Math.Max(W[(int)g - 1], 0.1);

    private static double InitDifficulty(Grade g) =>
        Math.Clamp(W[4] - ((int)g - 3) * W[5], 1.0, 10.0);

    private static double NextDifficulty(double d, Grade g)
    {
        var next = d - W[6] * ((int)g - 3);
        return Math.Clamp(W[7] * InitDifficulty(Grade.Easy) + (1 - W[7]) * next, 1.0, 10.0);
    }

    private static double RecallStability(double d, double s, double r, Grade g) =>
        s * (1 + Math.Exp(W[8]) * (11 - d) * Math.Pow(s, -W[9])
               * (Math.Exp(W[10] * (1 - r)) - 1)
               * (g == Grade.Hard ? W[15] : 1.0)
               * (g == Grade.Easy ? W[16] : 1.0));

    private static double ForgetStability(double d, double s, double r) =>
        Math.Min(W[11] * Math.Pow(d, -W[12]) * (Math.Pow(s + 1, W[13]) - 1)
                 * Math.Exp(W[14] * (1 - r)), s);

    public static void Review(ReviewCard card, Grade grade, DateTime now)
    {
        if (card.State == "new")
        {
            card.Stability = InitStability(grade);
            card.Difficulty = InitDifficulty(grade);
        }
        else
        {
            var days = Math.Max((now - (card.LastReview ?? now)).TotalDays, 0);
            var r = Retrievability(days, card.Stability);
            card.Difficulty = NextDifficulty(card.Difficulty, grade);
            card.Stability = grade == Grade.Again
                ? ForgetStability(card.Difficulty, card.Stability, r)
                : RecallStability(card.Difficulty, card.Stability, r, grade);
        }

        card.Reps++;
        card.LastReview = now;
        if (grade == Grade.Again)
        {
            card.State = "relearning";
            card.Due = now.AddMinutes(10);
        }
        else
        {
            card.State = "review";
            card.Due = now.AddDays(Math.Max(card.Stability, 1.0));
        }
    }
}
```

Run: `dotnet test QuestGraph.Tests --filter FsrsTests` â†’ PASS.

- [x] **Step 3: Write failing endpoint tests**

Append to `QuestGraph.Tests/FsrsTests.cs`:

```csharp
using System.Net.Http.Json;

public class ReviewEndpointTests : IClassFixture<TestAppFactory>
{
    private readonly HttpClient _client;
    public ReviewEndpointTests(TestAppFactory f) => _client = f.CreateClient();

    private record CardDto(Guid Id, string Front, string Back, DateTime Due, string State);

    [Fact]
    public async Task Create_grade_and_requeue_flow()
    {
        var reg = await _client.PostAsJsonAsync("/auth/register",
            new { email = $"{Guid.NewGuid():N}@t.com", password = "secret123", name = "R" });
        var token = (await reg.Content.ReadFromJsonAsync<Dictionary<string, string>>())!["token"];
        _client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);

        var created = await _client.PostAsJsonAsync("/reviews/cards",
            new { skillCode = "vocabulary.everyday", front = "hello", back = "xin chÃ o" });
        Assert.Equal(System.Net.HttpStatusCode.Created, created.StatusCode);

        var due = await _client.GetFromJsonAsync<List<CardDto>>("/reviews/due");
        var card = Assert.Single(due!);

        var graded = await _client.PostAsJsonAsync($"/reviews/{card.Id}/grade", new { rating = 3 });
        graded.EnsureSuccessStatusCode();

        var dueAfter = await _client.GetFromJsonAsync<List<CardDto>>("/reviews/due");
        Assert.Empty(dueAfter!);   // Good pushes it days into the future
    }
}
```

Run: `dotnet test QuestGraph.Tests --filter ReviewEndpointTests` â†’ FAIL.

- [x] **Step 4: Implement endpoints, verify pass**

`QuestGraph/Endpoints/ReviewEndpoints.cs`:

```csharp
using Microsoft.EntityFrameworkCore;
using QuestGraph.Data;
using QuestGraph.Domain;
using QuestGraph.Services;

namespace QuestGraph.Endpoints;

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
```

`AppDbContext`: `DbSet<ReviewCard> ReviewCards`; index `mb.Entity<ReviewCard>().HasIndex(c => new { c.UserId, c.Due });`
`Program.cs`: `app.MapReviews();`

Run: `dotnet test QuestGraph.Tests` â†’ PASS.

- [x] **Step 5: Migration + commit**

```powershell
dotnet ef migrations add AddReviewCards --project QuestGraph
git add -A
git commit -m "feat: FSRS-4.5 spaced repetition scheduler and review queue"
```
