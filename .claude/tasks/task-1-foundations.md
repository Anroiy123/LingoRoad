# Task 1: Foundations — repo scaffold, Postgres, EF Core, health, test infra

> Part of the QuestGraph plan. Read **Global Constraints** in `.claude/tasks/README.md` first.
> Execute with superpowers:subagent-driven-development or superpowers:executing-plans.

**Files:**
- Create: `docker-compose.yml`, `QuestGraph/Data/AppDbContext.cs`, `QuestGraph.Tests/` (new xUnit project), `QuestGraph.Tests/TestAppFactory.cs`, `QuestGraph.Tests/HealthTests.cs`
- Modify: `QuestGraph/Program.cs`, `QuestGraph/appsettings.Development.json`, `QuestGraph/QuestGraph.csproj`, `.gitignore`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: `AppDbContext` (empty, entities added by later tasks); `TestAppFactory : WebApplicationFactory<Program>` running on SQLite in-memory — every later .NET test uses it; `/health` endpoint; `docker compose up -d db` for local Postgres.

- [x] **Step 1: Create test project and wire solution**

```powershell
dotnet new xunit -n QuestGraph.Tests
dotnet sln add QuestGraph.Tests/QuestGraph.Tests.csproj
dotnet add QuestGraph.Tests package Microsoft.AspNetCore.Mvc.Testing
dotnet add QuestGraph.Tests package Microsoft.EntityFrameworkCore.Sqlite
dotnet add QuestGraph.Tests reference QuestGraph/QuestGraph.csproj
dotnet add QuestGraph package Npgsql.EntityFrameworkCore.PostgreSQL
dotnet add QuestGraph package Microsoft.EntityFrameworkCore.Design
```

- [x] **Step 2: Write the failing health test**

`QuestGraph.Tests/TestAppFactory.cs`:

```csharp
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using QuestGraph.Data;

namespace QuestGraph.Tests;

public class TestAppFactory : WebApplicationFactory<Program>
{
    private readonly SqliteConnection _conn = new("DataSource=:memory:");

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        _conn.Open();
        builder.ConfigureServices(services =>
        {
            // EF Core 9+/10: must also remove IDbContextOptionsConfiguration<T>,
            // otherwise the Npgsql provider stays registered alongside Sqlite.
            foreach (var d in services.Where(d =>
                         d.ServiceType == typeof(DbContextOptions<AppDbContext>) ||
                         d.ServiceType == typeof(IDbContextOptionsConfiguration<AppDbContext>))
                     .ToList())
                services.Remove(d);
            services.AddDbContext<AppDbContext>(o => o.UseSqlite(_conn));

            using var scope = services.BuildServiceProvider().CreateScope();
            scope.ServiceProvider.GetRequiredService<AppDbContext>()
                 .Database.EnsureCreated();
        });
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        _conn.Dispose();
    }
}
```

`QuestGraph.Tests/HealthTests.cs`:

```csharp
namespace QuestGraph.Tests;

public class HealthTests : IClassFixture<TestAppFactory>
{
    private readonly HttpClient _client;
    public HealthTests(TestAppFactory f) => _client = f.CreateClient();

    [Fact]
    public async Task Health_returns_ok()
    {
        var res = await _client.GetAsync("/health");
        res.EnsureSuccessStatusCode();
        Assert.Equal("ok", await res.Content.ReadAsStringAsync());
    }
}
```

- [x] **Step 3: Run test, verify it fails**

Run: `dotnet test QuestGraph.Tests`
Expected: FAIL — `AppDbContext` does not exist / 404 on `/health`.

- [x] **Step 4: Implement DbContext, Program.cs, docker-compose**

`QuestGraph/Data/AppDbContext.cs`:

```csharp
using Microsoft.EntityFrameworkCore;

namespace QuestGraph.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    // DbSets are added by later tasks (auth, skills, items, ...).
}
```

Replace `QuestGraph/Program.cs` entirely (deletes the weather-forecast template):

```csharp
using Microsoft.EntityFrameworkCore;
using QuestGraph.Data;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi();
builder.Services.AddDbContext<AppDbContext>(o =>
    o.UseNpgsql(builder.Configuration.GetConnectionString("Default")));

var app = builder.Build();

if (app.Environment.IsDevelopment())
    app.MapOpenApi();

app.MapGet("/health", () => Results.Text("ok"));

app.Run();

public partial class Program { } // exposes Program to WebApplicationFactory
```

`QuestGraph/appsettings.Development.json` — add connection string:

```json
{
  "Logging": { "LogLevel": { "Default": "Information", "Microsoft.AspNetCore": "Warning" } },
  "ConnectionStrings": {
    "Default": "Host=localhost;Database=questgraph;Username=questgraph;Password=questgraph"
  }
}
```

`docker-compose.yml` (repo root):

```yaml
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_DB: questgraph
      POSTGRES_USER: questgraph
      POSTGRES_PASSWORD: questgraph
    ports: ["5432:5432"]
    volumes: [pgdata:/var/lib/postgresql/data]
volumes:
  pgdata:
```

Append to `.gitignore`:

```
ml/data/
ml/checkpoints/
ml/.venv/
QuestGraph/wwwroot/uploads/
__pycache__/
```

- [x] **Step 5: Run test, verify it passes**

Run: `dotnet test QuestGraph.Tests`
Expected: PASS (1 test).

- [x] **Step 6: Verify Postgres + first migration**

```powershell
docker compose up -d db
dotnet tool install --global dotnet-ef
dotnet ef migrations add InitialCreate --project QuestGraph
dotnet ef database update --project QuestGraph
```

Expected: migration applies without error. (If Docker Desktop is unavailable, install PostgreSQL 16 locally with the same credentials — everything else is identical.)

- [x] **Step 7: Commit**

```powershell
git add -A
git commit -m "chore: scaffold API foundations - EF Core, Postgres, health endpoint, test infra"
```

Note: this is the repo's first commit and includes the previously staged template files — that is expected.
