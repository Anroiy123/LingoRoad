using System.ComponentModel.DataAnnotations;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using LingoRoad.Data;
using LingoRoad.Domain;
using LingoRoad.Services;

namespace LingoRoad.Endpoints;

public record RegisterRequest(string? Email, string? Password, string? Name);
public record LoginRequest(string? Email, string? Password);

public static class AuthEndpoints
{
    private static string NormalizeEmail(string? email) =>
        email?.Trim().ToLowerInvariant() ?? string.Empty;

    private static bool IsValidEmail(string email) =>
        email.Length <= 254 && new EmailAddressAttribute().IsValid(email);

    public static void MapAuth(this WebApplication app)
    {
        var g = app.MapGroup("/auth");

        g.MapPost("/register", async (RegisterRequest req, AppDbContext db, TokenService tokens) =>
        {
            var email = NormalizeEmail(req.Email);
            if (!IsValidEmail(email))
                return Results.BadRequest(new { error = "invalid_email" });
            if (req.Password is null || req.Password.Length < 8)
                return Results.BadRequest(new { error = "password_too_short" });
            if (req.Password.Length > 128)
                return Results.BadRequest(new { error = "password_too_long" });
            if (req.Name?.Length > 100)
                return Results.BadRequest(new { error = "name_too_long" });
            if (await db.Users.AnyAsync(u => u.Email == email))
                return Results.Conflict(new { error = "email_taken" });

            var user = new User
            {
                Email = email,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.Password),
                Name = string.IsNullOrWhiteSpace(req.Name) ? null : req.Name.Trim()
            };
            db.Users.Add(user);
            try
            {
                await db.SaveChangesAsync();
            }
            catch (DbUpdateException ex) when (
                ex.InnerException is PostgresException
                {
                    SqlState: PostgresErrorCodes.UniqueViolation
                })
            {
                return Results.Conflict(new { error = "email_taken" });
            }
            return Results.Created($"/users/{user.Id}", new { token = tokens.CreateToken(user) });
        });

        g.MapPost("/login", async (LoginRequest req, AppDbContext db, TokenService tokens) =>
        {
            var email = NormalizeEmail(req.Email);
            var user = IsValidEmail(email)
                ? await db.Users.SingleOrDefaultAsync(u => u.Email == email)
                : null;
            if (user is null || req.Password is null ||
                !BCrypt.Net.BCrypt.Verify(req.Password, user.PasswordHash))
                return Results.Unauthorized();
            return Results.Ok(new { token = tokens.CreateToken(user) });
        });
    }
}
