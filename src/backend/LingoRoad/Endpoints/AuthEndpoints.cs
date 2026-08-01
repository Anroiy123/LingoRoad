using System.ComponentModel.DataAnnotations;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using LingoRoad.Data;
using LingoRoad.Domain;
using LingoRoad.Services;

namespace LingoRoad.Endpoints;

public record RegisterRequest(string? Email, string? Password, string? Name);
public record LoginRequest(string? Email, string? Password);
public record RefreshRequest(string? RefreshToken);
public record LogoutRequest(string? RefreshToken);
public record ChangePasswordRequest(string? CurrentPassword, string? NewPassword);
public record UpdateProfileRequest(string? TargetCefr, int? DailyGoalMinutes,
    string? LearningPurpose, List<int>? FocusSkillIds, bool? StudyReminderEnabled,
    string? ReminderTime, string? TimeZone, bool? EmailNotifications, bool? AppUpdates);

public static class AuthEndpoints
{
    private static readonly HashSet<string> CefrLevels = ["A1", "A2", "B1", "B2"];

    private static string NormalizeEmail(string? email) =>
        email?.Trim().ToLowerInvariant() ?? string.Empty;

    private static bool IsValidEmail(string email) =>
        email.Length <= 254 && new EmailAddressAttribute().IsValid(email);

    public static void MapAuth(this WebApplication app)
    {
        var g = app.MapGroup("/auth");

        g.MapPost("/register", async (RegisterRequest req, AppDbContext db,
            TokenService tokens) =>
        {
            var email = NormalizeEmail(req.Email);
            if (!IsValidEmail(email)) return ApiResults.Error("invalid_email");
            var passwordError = ValidatePassword(req.Password);
            if (passwordError is not null) return ApiResults.Error(passwordError);
            if (req.Name?.Length > 100) return ApiResults.Error("name_too_long");
            if (await db.Users.AnyAsync(u => u.Email == email))
                return Results.Conflict(new { error = "email_taken" });

            var user = new User
            {
                Email = email,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.Password!),
                Name = string.IsNullOrWhiteSpace(req.Name) ? null : req.Name.Trim()
            };
            db.Users.Add(user);
            try
            {
                await db.SaveChangesAsync();
            }
            catch (DbUpdateException ex) when (ex.InnerException is PostgresException
                { SqlState: PostgresErrorCodes.UniqueViolation })
            {
                return Results.Conflict(new { error = "email_taken" });
            }
            return Results.Created($"/users/{user.Id}", await IssueSession(user, db, tokens));
        }).RequireRateLimiting("auth-write");

        g.MapPost("/login", async (LoginRequest req, AppDbContext db,
            TokenService tokens) =>
        {
            var email = NormalizeEmail(req.Email);
            var user = IsValidEmail(email)
                ? await db.Users.SingleOrDefaultAsync(u => u.Email == email) : null;
            if (user is null || req.Password is null ||
                !BCrypt.Net.BCrypt.Verify(req.Password, user.PasswordHash))
            {
                db.SecurityAuditEvents.Add(new SecurityAuditEvent
                    { EventType = "login_failed", Detail = email[..Math.Min(email.Length, 254)] });
                await db.SaveChangesAsync();
                return Results.Unauthorized();
            }
            db.SecurityAuditEvents.Add(new SecurityAuditEvent
                { UserId = user.Id, EventType = "login_succeeded" });
            return Results.Ok(await IssueSession(user, db, tokens));
        }).RequireRateLimiting("auth-write");

        g.MapPost("/refresh", async (RefreshRequest req, AppDbContext db,
            TokenService tokens) =>
        {
            if (string.IsNullOrWhiteSpace(req.RefreshToken)) return Results.Unauthorized();
            var hash = TokenService.HashRefreshToken(req.RefreshToken);
            var session = await db.RefreshSessions.SingleOrDefaultAsync(s => s.TokenHash == hash);
            if (session is null) return Results.Unauthorized();
            if (session.RevokedAt is not null)
            {
                var now = DateTime.UtcNow;
                await db.RefreshSessions.Where(s => s.UserId == session.UserId &&
                    s.FamilyId == session.FamilyId && s.RevokedAt == null)
                    .ExecuteUpdateAsync(x => x.SetProperty(s => s.RevokedAt, now));
                db.SecurityAuditEvents.Add(new SecurityAuditEvent
                    { UserId = session.UserId, EventType = "refresh_reuse_detected" });
                await db.SaveChangesAsync();
                return Results.Unauthorized();
            }
            if (session.ExpiresAt <= DateTime.UtcNow) return Results.Unauthorized();
            var user = await db.Users.FindAsync(session.UserId);
            if (user is null) return Results.Unauthorized();

            var refreshToken = tokens.CreateRefreshToken();
            var replacement = NewRefreshSession(user.Id, session.FamilyId, refreshToken);
            session.RevokedAt = DateTime.UtcNow;
            session.ReplacedById = replacement.Id;
            db.RefreshSessions.Add(replacement);
            try
            {
                await db.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                db.ChangeTracker.Clear();
                var now = DateTime.UtcNow;
                await db.RefreshSessions.Where(s => s.UserId == session.UserId &&
                    s.FamilyId == session.FamilyId && s.RevokedAt == null)
                    .ExecuteUpdateAsync(x => x.SetProperty(s => s.RevokedAt, now));
                db.SecurityAuditEvents.Add(new SecurityAuditEvent
                    { UserId = session.UserId, EventType = "refresh_reuse_detected" });
                await db.SaveChangesAsync();
                return Results.Unauthorized();
            }
            return Results.Ok(AuthResponse(user, tokens, refreshToken));
        }).RequireRateLimiting("refresh");

        g.MapPost("/logout", async (LogoutRequest req, AppDbContext db) =>
        {
            if (!string.IsNullOrWhiteSpace(req.RefreshToken))
            {
                var hash = TokenService.HashRefreshToken(req.RefreshToken);
                var session = await db.RefreshSessions.SingleOrDefaultAsync(s => s.TokenHash == hash);
                if (session is not null && session.RevokedAt is null)
                {
                    session.RevokedAt = DateTime.UtcNow;
                    await db.SaveChangesAsync();
                }
            }
            return Results.NoContent();
        }).RequireRateLimiting("refresh");

        g.MapPost("/change-password", async (ChangePasswordRequest req,
            System.Security.Claims.ClaimsPrincipal principal, AppDbContext db) =>
        {
            var passwordError = ValidatePassword(req.NewPassword);
            if (passwordError is not null) return ApiResults.Error(passwordError);
            var userId = principal.UserId();
            var user = await db.Users.FindAsync(userId);
            if (user is null) return Results.NotFound();
            if (req.CurrentPassword is null ||
                !BCrypt.Net.BCrypt.Verify(req.CurrentPassword, user.PasswordHash))
                return Results.BadRequest(new { error = "current_password_invalid" });
            user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.NewPassword!);
            var now = DateTime.UtcNow;
            await db.RefreshSessions.Where(s => s.UserId == userId && s.RevokedAt == null)
                .ExecuteUpdateAsync(x => x.SetProperty(s => s.RevokedAt, now));
            db.SecurityAuditEvents.Add(new SecurityAuditEvent
                { UserId = userId, EventType = "password_changed" });
            await db.SaveChangesAsync();
            return Results.NoContent();
        }).RequireAuthorization();

        g.MapPatch("/me", async (UpdateProfileRequest req,
            System.Security.Claims.ClaimsPrincipal principal, AppDbContext db) =>
        {
            var userId = principal.UserId();
            var user = await db.Users.FindAsync(userId);
            if (user is null) return Results.NotFound();
            if (req.TargetCefr is not null && !CefrLevels.Contains(req.TargetCefr))
                return ApiResults.Error("invalid_target_cefr");
            if (req.DailyGoalMinutes is < 10 or > 120)
                return ApiResults.Error("invalid_daily_goal");
            if (req.LearningPurpose?.Length > 100)
                return ApiResults.Error("learning_purpose_too_long");
            if (req.TimeZone?.Length > 100)
                return ApiResults.Error("timezone_too_long");
            if (req.ReminderTime is not null &&
                !TimeOnly.TryParseExact(req.ReminderTime, "HH:mm", out _))
                return ApiResults.Error("invalid_reminder_time");
            var focusIds = req.FocusSkillIds?.Distinct().ToList();
            if (focusIds is not null && await db.Skills.CountAsync(s => focusIds.Contains(s.Id)) != focusIds.Count)
                return ApiResults.Error("invalid_focus_skill");

            if (req.TargetCefr is not null)
            {
                user.TargetCefr = req.TargetCefr;
                user.TargetCefrConfirmed = true;
            }
            if (req.DailyGoalMinutes is not null) user.DailyGoalMinutes = req.DailyGoalMinutes.Value;
            if (req.LearningPurpose is not null) user.LearningPurpose = req.LearningPurpose.Trim();
            if (req.StudyReminderEnabled is not null) user.StudyReminderEnabled = req.StudyReminderEnabled.Value;
            if (req.ReminderTime is not null) user.ReminderTime = req.ReminderTime;
            if (req.TimeZone is not null) user.TimeZone = req.TimeZone.Trim();
            if (req.EmailNotifications is not null) user.EmailNotifications = req.EmailNotifications.Value;
            if (req.AppUpdates is not null) user.AppUpdates = req.AppUpdates.Value;
            if (focusIds is not null)
            {
                await db.UserFocusSkills.Where(x => x.UserId == userId).ExecuteDeleteAsync();
                db.UserFocusSkills.AddRange(focusIds.Select(id => new UserFocusSkill
                    { UserId = userId, SkillId = id }));
            }
            await db.SaveChangesAsync();
            return Results.Ok(await Profile(user, db));
        }).RequireAuthorization();

        g.MapGet("/me", async (System.Security.Claims.ClaimsPrincipal principal, AppDbContext db) =>
        {
            var user = await db.Users.FindAsync(principal.UserId());
            return user is null ? Results.NotFound() : Results.Ok(await Profile(user, db));
        }).RequireAuthorization();
    }

    private static string? ValidatePassword(string? password) => password switch
    {
        null => "password_too_short",
        { Length: < 8 } => "password_too_short",
        { Length: > 128 } => "password_too_long",
        _ => null
    };

    private static RefreshSession NewRefreshSession(Guid userId, Guid familyId, string token) => new()
    {
        UserId = userId, FamilyId = familyId,
        TokenHash = TokenService.HashRefreshToken(token),
        ExpiresAt = DateTime.UtcNow.AddDays(30)
    };

    private static async Task<object> IssueSession(User user, AppDbContext db, TokenService tokens)
    {
        var refreshToken = tokens.CreateRefreshToken();
        db.RefreshSessions.Add(NewRefreshSession(user.Id, Guid.NewGuid(), refreshToken));
        await db.SaveChangesAsync();
        return AuthResponse(user, tokens, refreshToken);
    }

    private static object AuthResponse(User user, TokenService tokens, string refreshToken)
    {
        var accessToken = tokens.CreateAccessToken(user);
        return new { token = accessToken, accessToken, refreshToken };
    }

    private static async Task<object> Profile(User user, AppDbContext db)
    {
        var lastSession = await db.TestSessions.Where(s => s.UserId == user.Id && s.Status == "completed")
            .OrderByDescending(s => s.CompletedAt).FirstOrDefaultAsync();
        var masteryCount = await db.Masteries.CountAsync(m => m.UserId == user.Id);
        var focusSkillIds = await db.UserFocusSkills.Where(x => x.UserId == user.Id)
            .Select(x => x.SkillId).ToListAsync();
        return new
        {
            id = user.Id, user.Email, name = user.Name ?? user.Email.Split('@')[0],
            user.TargetCefr, user.TargetCefrConfirmed,
            cefrLevel = lastSession?.ResultCefr ?? "A1",
            level = (masteryCount / 3) + 1,
            badgesCount = masteryCount >= 5 ? 3 : masteryCount >= 2 ? 2 : 1,
            user.DailyGoalMinutes, user.LearningPurpose, focusSkillIds,
            user.StudyReminderEnabled, user.ReminderTime, user.TimeZone,
            user.EmailNotifications, user.AppUpdates, user.Role
        };
    }
}
