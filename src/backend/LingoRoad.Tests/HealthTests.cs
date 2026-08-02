using System.Net;
using System.Net.Http.Json;
using LingoRoad.Data;
using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.Extensions.DependencyInjection;

namespace LingoRoad.Tests;

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

    [Fact]
    public async Task Ready_checks_database_connectivity()
    {
        var res = await _client.GetAsync("/ready");
        res.EnsureSuccessStatusCode();
        var body = await res.Content.ReadFromJsonAsync<Dictionary<string, string>>();
        Assert.Equal("ready", body?["database"]);
    }

    [Fact]
    public async Task Ready_returns_503_when_database_is_unavailable()
    {
        using var factory = new UnavailableDatabaseFactory();
        using var client = factory.CreateClient();

        var res = await client.GetAsync("/ready");

        Assert.Equal(HttpStatusCode.ServiceUnavailable, res.StatusCode);
        var body = await res.Content.ReadFromJsonAsync<Dictionary<string, string>>();
        Assert.Equal("unavailable", body?["database"]);
    }

    private sealed class UnavailableDatabaseFactory : TestAppFactory
    {
        private readonly string _missingDatabase =
            $"lingoroad-missing-{Guid.NewGuid():N}.db";

        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            base.ConfigureWebHost(builder);
            builder.ConfigureServices(services =>
            {
                foreach (var descriptor in services.Where(descriptor =>
                             descriptor.ServiceType == typeof(DbContextOptions<AppDbContext>) ||
                             descriptor.ServiceType == typeof(IDbContextOptionsConfiguration<AppDbContext>))
                         .ToList())
                    services.Remove(descriptor);

                services.AddDbContext<AppDbContext>(options =>
                    options.UseSqlite($"Data Source={_missingDatabase};Mode=ReadOnly"));
            });
        }
    }
}
