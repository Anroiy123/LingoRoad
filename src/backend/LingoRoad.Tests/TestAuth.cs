using System.Net.Http.Headers;
using Microsoft.Extensions.DependencyInjection;
using LingoRoad.Data;
using LingoRoad.Domain;
using LingoRoad.Services;

namespace LingoRoad.Tests;

internal static class TestAuth
{
    public static async Task<HttpClient> ClientAsync(TestAppFactory factory,
        string role = UserRoles.Admin)
    {
        var client = factory.CreateClient();
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var user = new User
        {
            Email = $"{role.ToLowerInvariant()}-{Guid.NewGuid():N}@example.test",
            Name = role,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("AdminPassword123"),
            Role = role
        };
        db.Users.Add(user);
        await db.SaveChangesAsync();
        var token = scope.ServiceProvider.GetRequiredService<TokenService>().CreateAccessToken(user);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return client;
    }
}
