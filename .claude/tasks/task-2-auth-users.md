# Task 2: Auth & Users — JWT register/login

> Part of the QuestGraph plan. Read **Global Constraints** in `.claude/tasks/README.md` first.
> Depends on: task-1.

**Files:**
- Create: `QuestGraph/Domain/User.cs`, `QuestGraph/Services/TokenService.cs`, `QuestGraph/Endpoints/AuthEndpoints.cs`, `QuestGraph.Tests/AuthTests.cs`
- Modify: `QuestGraph/Data/AppDbContext.cs`, `QuestGraph/Program.cs`, `QuestGraph/appsettings.Development.json`

**Interfaces:**
- Consumes: `AppDbContext`, `TestAppFactory` (task-1).
- Produces: `User` entity; `POST /auth/register` and `POST /auth/login` returning `{ "token": string }`; JWT bearer auth with user id in `ClaimTypes.NameIdentifier`; extension `Guid UserId(this ClaimsPrincipal)` used by all later authenticated endpoints; `TokenService.CreateToken(User) : string`.

- [x] **Step 1: Add packages**

```powershell
dotnet add QuestGraph package Microsoft.AspNetCore.Authentication.JwtBearer
dotnet add QuestGraph package BCrypt.Net-Next
```

- [x] **Step 2: Write the failing tests**

`QuestGraph.Tests/AuthTests.cs`:

```csharp
using System.Net;
using System.Net.Http.Json;

namespace QuestGraph.Tests;

public class AuthTests : IClassFixture<TestAppFactory>
{
    private readonly HttpClient _client;
    public AuthTests(TestAppFactory f) => _client = f.CreateClient();

    [Fact]
    public async Task Register_then_login_returns_token()
    {
        var reg = await _client.PostAsJsonAsync("/auth/register",
            new { email = "a@b.com", password = "secret123", name = "An" });
        Assert.Equal(HttpStatusCode.Created, reg.StatusCode);

        var login = await _client.PostAsJsonAsync("/auth/login",
            new { email = "a@b.com", password = "secret123" });
        login.EnsureSuccessStatusCode();
        var body = await login.Content.ReadFromJsonAsync<Dictionary<string, string>>();
        Assert.False(string.IsNullOrEmpty(body!["token"]));
    }

    [Fact]
    public async Task Login_with_wrong_password_returns_401()
    {
        await _client.PostAsJsonAsync("/auth/register",
            new { email = "c@d.com", password = "secret123", name = "Chi" });
        var login = await _client.PostAsJsonAsync("/auth/login",
            new { email = "c@d.com", password = "WRONG" });
        Assert.Equal(HttpStatusCode.Unauthorized, login.StatusCode);
    }

    [Fact]
    public async Task Duplicate_email_returns_409()
    {
        await _client.PostAsJsonAsync("/auth/register",
            new { email = "e@f.com", password = "secret123", name = "E" });
        var dup = await _client.PostAsJsonAsync("/auth/register",
            new { email = "e@f.com", password = "secret123", name = "E2" });
        Assert.Equal(HttpStatusCode.Conflict, dup.StatusCode);
    }
}
```

- [x] **Step 3: Run tests, verify they fail**

Run: `dotnet test QuestGraph.Tests --filter AuthTests`
Expected: FAIL — 404 (endpoints don't exist).

- [x] **Step 4: Implement entity, token service, endpoints**

`QuestGraph/Domain/User.cs`:

```csharp
namespace QuestGraph.Domain;

public class User
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public required string Email { get; set; }
    public required string PasswordHash { get; set; }
    public string? Name { get; set; }
    public string TargetCefr { get; set; } = "B2";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
```

In `AppDbContext` add:

```csharp
public DbSet<User> Users => Set<User>();

protected override void OnModelCreating(ModelBuilder mb)
{
    mb.Entity<User>().HasIndex(u => u.Email).IsUnique();
}
```

(add `using QuestGraph.Domain;`)

`QuestGraph/Services/TokenService.cs`:

```csharp
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.IdentityModel.Tokens;
using QuestGraph.Domain;

namespace QuestGraph.Services;

public class TokenService(IConfiguration config)
{
    public string CreateToken(User user)
    {
        var key = new SymmetricSecurityKey(
            Encoding.UTF8.GetBytes(config["Jwt:Secret"]!));
        var token = new JwtSecurityToken(
            issuer: config["Jwt:Issuer"],
            claims: [
                new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
                new Claim(ClaimTypes.Email, user.Email)
            ],
            expires: DateTime.UtcNow.AddDays(7),
            signingCredentials: new SigningCredentials(key, SecurityAlgorithms.HmacSha256));
        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}

public static class ClaimsExtensions
{
    public static Guid UserId(this ClaimsPrincipal user) =>
        Guid.Parse(user.FindFirstValue(ClaimTypes.NameIdentifier)!);
}
```

`QuestGraph/Endpoints/AuthEndpoints.cs`:

```csharp
using Microsoft.EntityFrameworkCore;
using QuestGraph.Data;
using QuestGraph.Domain;
using QuestGraph.Services;

namespace QuestGraph.Endpoints;

public record RegisterRequest(string Email, string Password, string? Name);
public record LoginRequest(string Email, string Password);

public static class AuthEndpoints
{
    public static void MapAuth(this WebApplication app)
    {
        var g = app.MapGroup("/auth");

        g.MapPost("/register", async (RegisterRequest req, AppDbContext db, TokenService tokens) =>
        {
            if (req.Password.Length < 8)
                return Results.BadRequest(new { error = "password_too_short" });
            if (await db.Users.AnyAsync(u => u.Email == req.Email))
                return Results.Conflict(new { error = "email_taken" });

            var user = new User
            {
                Email = req.Email,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.Password),
                Name = req.Name
            };
            db.Users.Add(user);
            await db.SaveChangesAsync();
            return Results.Created($"/users/{user.Id}", new { token = tokens.CreateToken(user) });
        });

        g.MapPost("/login", async (LoginRequest req, AppDbContext db, TokenService tokens) =>
        {
            var user = await db.Users.SingleOrDefaultAsync(u => u.Email == req.Email);
            if (user is null || !BCrypt.Net.BCrypt.Verify(req.Password, user.PasswordHash))
                return Results.Unauthorized();
            return Results.Ok(new { token = tokens.CreateToken(user) });
        });
    }
}
```

In `Program.cs` — before `builder.Build()`:

```csharp
builder.Services.AddSingleton<TokenService>();
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o => o.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidIssuer = builder.Configuration["Jwt:Issuer"],
        ValidateAudience = false,
        IssuerSigningKey = new SymmetricSecurityKey(
            Encoding.UTF8.GetBytes(builder.Configuration["Jwt:Secret"]!))
    });
builder.Services.AddAuthorization();
```

after `var app = builder.Build();`:

```csharp
app.UseAuthentication();
app.UseAuthorization();
app.MapAuth();
```

(usings: `Microsoft.AspNetCore.Authentication.JwtBearer`, `Microsoft.IdentityModel.Tokens`, `System.Text`, `QuestGraph.Endpoints`, `QuestGraph.Services`)

`appsettings.Development.json` — add:

```json
"Jwt": {
  "Issuer": "questgraph",
  "Secret": "dev-only-secret-change-me-0123456789abcdef"
}
```

- [x] **Step 5: Run tests, verify they pass**

Run: `dotnet test QuestGraph.Tests`
Expected: PASS (all tests, including task-1's).

- [x] **Step 6: Migration + commit**

```powershell
dotnet ef migrations add AddUsers --project QuestGraph
dotnet ef database update --project QuestGraph
git add -A
git commit -m "feat: JWT auth with register/login"
```
