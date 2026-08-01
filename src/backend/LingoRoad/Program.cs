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

var builder = WebApplication.CreateBuilder(args);

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
builder.Services.AddDbContext<AppDbContext>(o =>
    o.UseNpgsql(builder.Configuration.GetConnectionString("Default")));

builder.Services.AddSingleton<TokenService>();
builder.Services.AddScoped<MasteryService>();
builder.Services.AddHttpClient<IMlClient, MlClient>(c =>
{
    c.BaseAddress = new Uri(builder.Configuration["MlService:BaseUrl"] ?? "http://localhost:8001");
    c.Timeout = TimeSpan.FromSeconds(30);
    var internalToken = builder.Configuration["MlService:InternalToken"];
    if (!string.IsNullOrWhiteSpace(internalToken))
        c.DefaultRequestHeaders.Add("X-Internal-Token", internalToken);
});
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o => o.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidIssuer = builder.Configuration["Jwt:Issuer"],
        ValidateAudience = false,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ClockSkew = TimeSpan.FromSeconds(30),
        IssuerSigningKey = new SymmetricSecurityKey(
            Encoding.UTF8.GetBytes(builder.Configuration["Jwt:Secret"]!))
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
    if (app.Environment.IsDevelopment() &&
        (app.Configuration.GetValue<bool?>("ContentSeed:Enabled") ?? true))
        await DbSeeder.SeedAsync(db);
    await AdminBootstrapper.BootstrapAsync(db, app.Configuration);
}

app.UseStaticFiles(); // serves wwwroot/ (listening audio under /audio)
app.UseCors();
app.UseAuthentication();
app.UseRateLimiter();
app.UseAuthorization();

app.MapGet("/health", () => Results.Text("ok"));
app.MapAuth();
app.MapSkills();
app.MapItems();
app.MapPlacement();
app.MapMastery();
app.MapReviews();
app.MapPath();
app.MapExercises();
app.MapLessons();
app.MapSpeaking();

app.Run();

public partial class Program { } // exposes Program to WebApplicationFactory
