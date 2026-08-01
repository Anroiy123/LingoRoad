using System.ComponentModel.DataAnnotations;
using Microsoft.EntityFrameworkCore;
using LingoRoad.Data;
using LingoRoad.Domain;

namespace LingoRoad.Services;

public static class AdminBootstrapper
{
    public static async Task BootstrapAsync(AppDbContext db, IConfiguration config)
    {
        var email = config["BootstrapAdmin:Email"]?.Trim().ToLowerInvariant();
        var password = config["BootstrapAdmin:Password"];
        if (string.IsNullOrEmpty(email) && string.IsNullOrEmpty(password)) return;
        if (email is null || password is null || password.Length < 12 ||
            !new EmailAddressAttribute().IsValid(email))
            throw new InvalidOperationException(
                "BootstrapAdmin requires a valid Email and Password of at least 12 characters.");

        var user = await db.Users.SingleOrDefaultAsync(x => x.Email == email);
        if (user is null)
        {
            user = new User
            {
                Email = email,
                Name = "Administrator",
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(password),
                Role = UserRoles.Admin
            };
            db.Users.Add(user);
        }
        else
        {
            user.Role = UserRoles.Admin;
        }
        db.SecurityAuditEvents.Add(new SecurityAuditEvent
            { UserId = user.Id, EventType = "admin_bootstrapped" });
        await db.SaveChangesAsync();
    }
}
