using System.Text;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Scalar.AspNetCore;
using LingoRoad.Data;
using LingoRoad.Endpoints;
using LingoRoad.Services;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

var builder = WebApplication.CreateBuilder(args);

var migrateOnly = args.Contains("--migrate-only", StringComparer.OrdinalIgnoreCase);
var seedOnly = args.Contains("--seed-only", StringComparer.OrdinalIgnoreCase);

if (builder.Environment.IsProduction())
{
    builder.Logging.ClearProviders();
    builder.Logging.AddJsonConsole(options => options.IncludeScopes = true);
}

if (!builder.Environment.IsDevelopment() && !builder.Environment.IsEnvironment("Testing"))
{
    static void Required(IConfiguration config, string key, int minLength = 1)
    {
        if ((config[key]?.Trim().Length ?? 0) < minLength)
            throw new InvalidOperationException($"Missing or invalid production configuration: {key}");
    }
    Required(builder.Configuration, "ConnectionStrings:Default");
    Required(builder.Configuration, "Jwt:Issuer");
    Required(builder.Configuration, "Jwt:Secret", 32);
    Required(builder.Configuration, "MlService:BaseUrl");
    Required(builder.Configuration, "MlService:InternalToken", 32);
    Required(builder.Configuration, "Storage:TempPath");
    if (builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() is not { Length: > 0 })
        throw new InvalidOperationException("Missing production configuration: Cors:AllowedOrigins");
}

builder.Services.AddOpenApi();
builder.Services.AddProblemDetails();
builder.Services.AddOpenTelemetry()
    .ConfigureResource(resource => resource.AddService("lingoroad-api"))
    .WithTracing(tracing => tracing
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddOtlpExporter())
    .WithMetrics(metrics => metrics
        .AddAspNetCoreInstrumentation()
        .AddRuntimeInstrumentation()
        .AddOtlpExporter());
builder.Services.AddDbContext<AppDbContext>(o =>
    o.UseNpgsql(builder.Configuration.GetConnectionString("Default")));

builder.Services.AddSingleton<TokenService>();
builder.Services.AddSingleton<MlCircuitBreaker>();
builder.Services.AddScoped<MasteryService>();
builder.Services.AddScoped<GamificationService>();
builder.Services.AddScoped<LearningQualityService>();
builder.Services.AddScoped<PrivacyDeletionService>();
builder.Services.AddScoped<DataRetentionService>();
if (!builder.Environment.IsEnvironment("Testing"))
    builder.Services.AddHostedService<PrivacyMaintenanceWorker>();
builder.Services.AddHttpClient<IMlClient, MlClient>(c =>
{
    c.BaseAddress = new Uri(builder.Configuration["MlService:BaseUrl"] ?? "http://localhost:8001");
    c.Timeout = Timeout.InfiniteTimeSpan;
    var internalToken = builder.Configuration["MlService:InternalToken"];
    if (!string.IsNullOrWhiteSpace(internalToken))
        c.DefaultRequestHeaders.Add("X-Internal-Token", internalToken);
});
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o =>
    {
        o.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = builder.Configuration["Jwt:Issuer"],
            ValidateAudience = false,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ClockSkew = TimeSpan.FromSeconds(30),
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(builder.Configuration["Jwt:Secret"]!))
        };
        o.Events = new JwtBearerEvents
        {
            OnTokenValidated = async context =>
            {
                var value = context.Principal?.FindFirst(
                    System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
                if (!Guid.TryParse(value, out var userId))
                {
                    context.Fail("invalid_user");
                    return;
                }
                var db = context.HttpContext.RequestServices
                    .GetRequiredService<AppDbContext>();
                var state = await db.Users.Where(user => user.Id == userId)
                    .Select(_ => new
                    {
                        DeletionPending = db.AccountDeletionRequests.Any(request =>
                            request.UserId == userId &&
                            request.Status ==
                                LingoRoad.Domain.AccountDeletionStatuses.Pending)
                    })
                    .SingleOrDefaultAsync(context.HttpContext.RequestAborted);
                if (state is null)
                    context.Fail("user_not_found");
                else if (state.DeletionPending &&
                    !(HttpMethods.IsDelete(context.Request.Method) &&
                      context.Request.Path.Equals("/auth/me")))
                    context.Fail("account_deletion_pending");
            }
        };
    });
builder.Services.AddAuthorization(options =>
    options.AddPolicy("Admin", policy => policy.RequireRole("Admin")));
builder.Services.AddAntiforgery();
builder.Services.AddCors(options => options.AddDefaultPolicy(policy =>
{
    var origins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
    if (origins.Length > 0) policy.WithOrigins(origins).AllowAnyHeader().AllowAnyMethod();
}));
builder.Services.AddRateLimiter(options =>
{
    static FixedWindowRateLimiterOptions Fixed(int limit) => new()
    {
        PermitLimit = limit,
        Window = TimeSpan.FromMinutes(1),
        QueueLimit = 0,
        AutoReplenishment = true
    };
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    var anonymousLimit = builder.Configuration.GetValue<int?>("RateLimits:Anonymous") ?? 60;
    var authenticatedLimit = builder.Configuration.GetValue<int?>("RateLimits:Authenticated") ?? 120;
    var authWriteLimit = builder.Configuration.GetValue<int?>("RateLimits:AuthWrite") ?? 5;
    var refreshLimit = builder.Configuration.GetValue<int?>("RateLimits:Refresh") ?? 10;
    var mlUploadLimit = builder.Configuration.GetValue<int?>("RateLimits:MlUpload") ?? 10;
    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context =>
        RateLimitPartition.GetFixedWindowLimiter(
            context.User.Identity?.IsAuthenticated == true
                ? context.User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value ?? "user"
                : context.Connection.RemoteIpAddress?.ToString() ?? "anonymous",
            _ => Fixed(context.User.Identity?.IsAuthenticated == true ? authenticatedLimit : anonymousLimit)));
    options.AddPolicy("auth-write", context => RateLimitPartition.GetFixedWindowLimiter(
        context.Connection.RemoteIpAddress?.ToString() ?? "anonymous", _ => Fixed(authWriteLimit)));
    options.AddPolicy("refresh", context => RateLimitPartition.GetFixedWindowLimiter(
        context.Connection.RemoteIpAddress?.ToString() ?? "anonymous", _ => Fixed(refreshLimit)));
    options.AddPolicy("ml-upload", context => RateLimitPartition.GetFixedWindowLimiter(
        context.User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value ??
        context.Connection.RemoteIpAddress?.ToString() ?? "anonymous", _ => Fixed(mlUploadLimit)));
});

var app = builder.Build();

app.UseExceptionHandler();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference();
}

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    if (migrateOnly)
    {
        await db.Database.MigrateAsync();
        app.Logger.LogInformation("Database migration one-shot completed successfully");
        return;
    }
    if (seedOnly)
    {
        await DbSeeder.SeedAsync(db);
        app.Logger.LogInformation("Content seed one-shot completed successfully");
        return;
    }
    if (app.Environment.IsDevelopment() &&
        (app.Configuration.GetValue<bool?>("ContentSeed:Enabled") ?? true))
        await DbSeeder.SeedAsync(db);
    await AdminBootstrapper.BootstrapAsync(db, app.Configuration);
}

app.UseStaticFiles(); // public content assets only; raw speaking audio is never stored here
app.UseCors();
app.UseAuthentication();
app.UseRateLimiter();
app.UseAuthorization();

app.MapGet("/health", () => Results.Text("ok"));
app.MapGet("/ready", async (AppDbContext db, CancellationToken cancellationToken) =>
{
    try
    {
        return await db.Database.CanConnectAsync(cancellationToken)
            ? Results.Ok(new { status = "ready", database = "ready" })
            : Results.Json(
                new { status = "not_ready", database = "unavailable" },
                statusCode: StatusCodes.Status503ServiceUnavailable);
    }
    catch
    {
        return Results.Json(
            new { status = "not_ready", database = "unavailable" },
            statusCode: StatusCodes.Status503ServiceUnavailable);
    }
});
app.MapAuth();
app.MapSkills();
app.MapItems();
app.MapPlacement();
app.MapMastery();
app.MapReviews();
app.MapPath();
app.MapExercises();
app.MapLessons();
app.MapDashboard();
app.MapSpeaking();
app.MapAdmin();
app.MapPrivacy();
app.MapDictionary();

app.Run();

public partial class Program { } // exposes Program to WebApplicationFactory
