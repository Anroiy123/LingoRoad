using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using LingoRoad.Data;

namespace LingoRoad.Tests;

public class TestAppFactory : WebApplicationFactory<Program>
{
    protected virtual bool SeedContent => false;
    private readonly string _connectionString = new SqliteConnectionStringBuilder
    {
        DataSource = $"lingoroad-tests-{Guid.NewGuid():N}",
        Mode = SqliteOpenMode.Memory,
        Cache = SqliteCacheMode.Shared,
        DefaultTimeout = 5,
    }.ToString();
    private readonly SqliteConnection _keeper;

    public TestAppFactory() => _keeper = new SqliteConnection(_connectionString);

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        _keeper.Open();
        builder.UseSetting("RateLimits:Anonymous", "10000");
        builder.UseSetting("RateLimits:Authenticated", "10000");
        builder.UseSetting("RateLimits:AuthWrite", "10000");
        builder.UseSetting("RateLimits:Refresh", "10000");
        builder.UseSetting("RateLimits:MlUpload", "10000");
        builder.UseSetting("ContentSeed:Enabled", SeedContent.ToString());
        builder.ConfigureServices(services =>
        {
            foreach (var d in services.Where(d =>
                         d.ServiceType == typeof(DbContextOptions<AppDbContext>) ||
                         d.ServiceType == typeof(IDbContextOptionsConfiguration<AppDbContext>))
                     .ToList())
                services.Remove(d);
            services.AddDbContext<AppDbContext>(o => o.UseSqlite(_connectionString));

            using var scope = services.BuildServiceProvider().CreateScope();
            scope.ServiceProvider.GetRequiredService<AppDbContext>()
                 .Database.EnsureCreated();
            DbSeeder.SeedAsync(scope.ServiceProvider.GetRequiredService<AppDbContext>(), SeedContent)
                .GetAwaiter().GetResult();
        });
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        _keeper.Dispose();
    }
}
