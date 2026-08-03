# Task 6: Placement Test Sessions — adaptive test end-to-end

> Part of the QuestGraph plan. Read **Global Constraints** in `.claude/tasks/README.md` first.
> Depends on: task-2 (auth), task-4 (items), task-5 (IMlClient).

**Files:**
- Create: `QuestGraph/Domain/TestSession.cs`, `QuestGraph/Domain/CefrMap.cs`, `QuestGraph/Endpoints/PlacementEndpoints.cs`, `QuestGraph/Endpoints/ApiResults.cs`, `QuestGraph.Tests/PlacementTests.cs`
- Modify: `QuestGraph/Data/AppDbContext.cs`, `QuestGraph/Program.cs`

**Interfaces:**
- Consumes: `IMlClient.CatSelectAsync`, `Item`, auth (`ClaimsPrincipal.UserId()`), `TestAppFactory`.
- Produces: entities `TestSession { Guid Id, Guid UserId, string Status, double Theta, double ThetaSe, DateTime StartedAt, DateTime? CompletedAt, string? ResultCefr }` and `Response { Guid Id, Guid SessionId, Guid ItemId, string? Answer, bool Correct, double ThetaAfter, double SeAfter, DateTime AnsweredAt }`; `CefrMap.FromTheta(double) : string`; `ApiResults.MlUnavailable()` (503 helper used by tasks 10/12/13/14); endpoints:
  - `POST /placement/start` → `{ sessionId, item: PlacementItemDto }`
  - `POST /placement/{sessionId}/answer` body `{ itemId, answer }` → `{ done:false, item }` or `{ done:true, theta, se, cefr }`
  - `GET /placement/{sessionId}/result` → `{ theta, se, cefr, itemsAnswered, status }`
  - `PlacementItemDto(Guid Id, string Type, string Stem, string[] Options, string? AudioUrl)` — never exposes `CorrectAnswer`.
- Stop rule constants (global): min 8 items, SE < 0.35, cap 30, or item pool exhausted.

- [x] **Step 1: Write failing tests**

`QuestGraph.Tests/PlacementTests.cs`:

```csharp
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using QuestGraph.Domain;
using QuestGraph.Services;

namespace QuestGraph.Tests;

/// Fake: theta creeps up, SE = 1/sqrt(n+1) so the stop rule (SE<0.35, min 8) fires after item 8.
public class FakeMlClient : IMlClient
{
    public bool Throw { get; set; }
    public Task<CatSelectResponse> CatSelectAsync(CatSelectRequest req, CancellationToken ct = default)
    {
        if (Throw) throw new MlServiceUnavailableException(new HttpRequestException("down"));
        var n = req.History.Count;
        var se = 1.0 / Math.Sqrt(n + 1);
        var next = req.Candidates.Count > 0 ? req.Candidates[0].ItemId : (Guid?)null;
        return Task.FromResult(new CatSelectResponse(0.1 * n, se, next));
    }
}

public class PlacementFactory : TestAppFactory
{
    public FakeMlClient Fake { get; } = new();
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        base.ConfigureWebHost(builder);
        builder.ConfigureServices(s =>
        {
            s.RemoveAll<IMlClient>();
            s.AddSingleton<IMlClient>(Fake);
        });
    }
}

public class PlacementTests : IClassFixture<PlacementFactory>
{
    private readonly PlacementFactory _factory;
    private readonly HttpClient _client;
    public PlacementTests(PlacementFactory f) { _factory = f; _client = f.CreateClient(); }

    private async Task AuthenticateAsync()
    {
        var email = $"{Guid.NewGuid():N}@t.com";
        var reg = await _client.PostAsJsonAsync("/auth/register",
            new { email, password = "secret123", name = "T" });
        var token = (await reg.Content.ReadFromJsonAsync<Dictionary<string, string>>())!["token"];
        _client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
    }

    private async Task SeedItemsAsync(int count = 12)
    {
        var items = Enumerable.Range(0, count).Select(i => new
        {
            skillCode = "grammar.tenses.present_simple",
            cefrLevel = "B1",
            type = "mcq",
            stem = $"Question {i}: she ___ tea.",
            options = new[] { "drinks", "drink", "drinking", "drank" },
            correctAnswer = "drinks",
            source = "test"
        });
        (await _client.PostAsJsonAsync("/admin/items/import", items)).EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task Full_adaptive_session_stops_after_min_items_and_returns_cefr()
    {
        await AuthenticateAsync();
        await SeedItemsAsync();
        _factory.Fake.Throw = false;

        var start = await _client.PostAsync("/placement/start", null);
        start.EnsureSuccessStatusCode();
        var state = await start.Content.ReadFromJsonAsync<StartDto>();
        var sessionId = state!.SessionId;

        int answered = 0;
        Guid itemId = state.Item.Id;
        while (true)
        {
            var res = await _client.PostAsJsonAsync($"/placement/{sessionId}/answer",
                new { itemId, answer = "drinks" });
            res.EnsureSuccessStatusCode();
            var step = await res.Content.ReadFromJsonAsync<StepDto>();
            answered++;
            if (step!.Done) break;
            itemId = step.Item!.Id;
            Assert.True(answered < 40, "session never terminated");
        }

        Assert.True(answered >= 8);
        var result = await _client.GetFromJsonAsync<ResultDto>($"/placement/{sessionId}/result");
        Assert.Equal("completed", result!.Status);
        Assert.Contains(result.Cefr, new[] { "A1", "A2", "B1", "B2", "C1", "C2" });
    }

    [Fact]
    public async Task Start_without_auth_returns_401()
    {
        var anon = _factory.CreateClient();
        var res = await anon.PostAsync("/placement/start", null);
        Assert.Equal(HttpStatusCode.Unauthorized, res.StatusCode);
    }

    [Fact]
    public async Task Ml_service_down_returns_503_with_error_body()
    {
        await AuthenticateAsync();
        await SeedItemsAsync(2);
        _factory.Fake.Throw = true;
        var res = await _client.PostAsync("/placement/start", null);
        Assert.Equal(HttpStatusCode.ServiceUnavailable, res.StatusCode);
        Assert.Contains("ml_service_unavailable", await res.Content.ReadAsStringAsync());
        _factory.Fake.Throw = false;
    }

    private record PlacementItem(Guid Id, string Type, string Stem, string[] Options, string? AudioUrl);
    private record StartDto(Guid SessionId, PlacementItem Item);
    private record StepDto(bool Done, PlacementItem? Item, double? Theta, string? Cefr);
    private record ResultDto(double Theta, double Se, string Cefr, int ItemsAnswered, string Status);
}
```

Also add a pure unit test for the CEFR mapping in the same file:

```csharp
public class CefrMapTests
{
    [Theory]
    [InlineData(-2.5, "A1")] [InlineData(-1.0, "A2")] [InlineData(0.0, "B1")]
    [InlineData(1.0, "B2")] [InlineData(2.0, "C1")] [InlineData(3.0, "C2")]
    public void Maps_theta_to_cefr(double theta, string expected) =>
        Assert.Equal(expected, CefrMap.FromTheta(theta));
}
```

- [x] **Step 2: Run tests, verify they fail**

Run: `dotnet test QuestGraph.Tests --filter "PlacementTests|CefrMapTests"` → FAIL.

- [x] **Step 3: Implement**

`QuestGraph/Domain/CefrMap.cs`:

```csharp
namespace QuestGraph.Domain;

public static class CefrMap
{
    public static string FromTheta(double theta) => theta switch
    {
        < -1.5 => "A1", < -0.5 => "A2", < 0.5 => "B1",
        < 1.5 => "B2", < 2.25 => "C1", _ => "C2"
    };
}
```

`QuestGraph/Domain/TestSession.cs`:

```csharp
namespace QuestGraph.Domain;

public class TestSession
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public string Status { get; set; } = "active";   // active | completed
    public double Theta { get; set; }
    public double ThetaSe { get; set; } = 1.0;
    public DateTime StartedAt { get; set; } = DateTime.UtcNow;
    public DateTime? CompletedAt { get; set; }
    public string? ResultCefr { get; set; }
}

public class Response
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid SessionId { get; set; }
    public Guid ItemId { get; set; }
    public string? Answer { get; set; }
    public bool Correct { get; set; }
    public double ThetaAfter { get; set; }
    public double SeAfter { get; set; }
    public DateTime AnsweredAt { get; set; } = DateTime.UtcNow;
}
```

`AppDbContext`: add `DbSet<TestSession> TestSessions`, `DbSet<Response> Responses`; index: `mb.Entity<Response>().HasIndex(r => r.SessionId);`

`QuestGraph/Endpoints/ApiResults.cs`:

```csharp
namespace QuestGraph.Endpoints;

public static class ApiResults
{
    public static IResult MlUnavailable() =>
        Results.Json(new { error = "ml_service_unavailable" }, statusCode: 503);
}
```

`QuestGraph/Endpoints/PlacementEndpoints.cs`:

```csharp
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using QuestGraph.Data;
using QuestGraph.Domain;
using QuestGraph.Services;

namespace QuestGraph.Endpoints;

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
            System.Security.Claims.ClaimsPrincipal user, AppDbContext db, IMlClient ml) =>
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
```

`Program.cs`: add `app.MapPlacement();`

- [x] **Step 4: Run tests, verify they pass**

Run: `dotnet test QuestGraph.Tests` → PASS (all suites).

- [x] **Step 5: Manual end-to-end check against the real ML service**

```powershell
docker compose up -d db
ml/.venv/Scripts/uvicorn questgraph_ml.serving.app:app --port 8001 --app-dir ml
dotnet run --project QuestGraph
```

Use `QuestGraph/QuestGraph.http` (or curl): register → start placement → answer a few items. Verify theta moves and SE shrinks between answers.

- [x] **Step 6: Migration + commit**

```powershell
dotnet ef migrations add AddTestSessions --project QuestGraph
git add -A
git commit -m "feat: adaptive placement test sessions end-to-end"
```
