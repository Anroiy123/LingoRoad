using System.ComponentModel;
using System.Diagnostics;
using System.Globalization;
using LingoRoad.Data;
using LingoRoad.Migrations;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.EntityFrameworkCore.Migrations.Operations;

namespace LingoRoad.Tests;

public class ProfileSetupMigrationTests
{
    private const string PreviousMigration =
        "20260811052419_AddQuestionReviewGradeAnswers";

    [Fact]
    public void Migration_operations_add_nullable_column_and_backfill_sql()
    {
        var migration = new ExposedProfileSetupMigration();
        var builder = new MigrationBuilder("Npgsql.EntityFrameworkCore.PostgreSQL");

        migration.Apply(builder);

        var column = Assert.Single(builder.Operations.OfType<AddColumnOperation>());
        Assert.Equal("Users", column.Table);
        Assert.Equal("ProfileSetupCompletedAt", column.Name);
        Assert.True(column.IsNullable);
        Assert.Equal("timestamp with time zone", column.ColumnType);

        var backfill = Assert.Single(builder.Operations.OfType<SqlOperation>());
        Assert.Equal(
            "UPDATE \"Users\" SET \"ProfileSetupCompletedAt\" = \"CreatedAt\" WHERE \"ProfileSetupCompletedAt\" IS NULL;",
            backfill.Sql);
    }

    [DockerAvailableFact]
    public async Task PostgreSql_migration_backfills_existing_user_and_leaves_new_user_null()
    {
        var dockerInfo = await RunDocker("info", "--format", "{{.ServerVersion}}");
        Assert.True(
            dockerInfo.Started && dockerInfo.ExitCode == 0,
            $"Docker became unavailable after test discovery: {dockerInfo.StandardError}");

        var suffix = Guid.NewGuid().ToString("N", CultureInfo.InvariantCulture);
        var containerName = $"lingoroad-profile-migration-{suffix}";
        var password = $"test-{suffix}";
        const string database = "lingoroad_profile_migration";
        var started = false;

        try
        {
            var run = await RunDocker(
                "run", "--detach", "--rm",
                "--name", containerName,
                "--publish", "127.0.0.1::5432",
                "--env", $"POSTGRES_PASSWORD={password}",
                "--env", $"POSTGRES_DB={database}",
                "postgres:16-alpine");
            Assert.True(run.ExitCode == 0, $"docker run failed: {run.StandardError}");
            started = true;

            var portResult = await RunDocker("port", containerName, "5432/tcp");
            Assert.True(
                portResult.ExitCode == 0,
                $"docker port failed: {portResult.StandardError}");
            var port = ParsePublishedPort(portResult.StandardOutput);

            var ready = false;
            for (var attempt = 0; attempt < 60; attempt++)
            {
                var readiness = await RunDocker(
                    "exec", containerName,
                    "pg_isready", "--username", "postgres", "--dbname", database);
                if (readiness.ExitCode == 0)
                {
                    ready = true;
                    break;
                }
                await Task.Delay(TimeSpan.FromMilliseconds(500));
            }
            Assert.True(ready, "Disposable PostgreSQL did not become ready within 30 seconds.");

            var connectionString =
                $"Host=127.0.0.1;Port={port};Database={database};Username=postgres;Password={password};Pooling=false";
            var options = new DbContextOptionsBuilder<AppDbContext>()
                .UseNpgsql(connectionString)
                .Options;
            await using var db = new AppDbContext(options);
            var migrator = db.GetService<IMigrator>();
            await migrator.MigrateAsync(PreviousMigration);

            var existingUserId = Guid.NewGuid();
            var existingCreatedAt = new DateTime(
                2026, 8, 11, 1, 2, 3, DateTimeKind.Utc);
            await db.Database.ExecuteSqlInterpolatedAsync($"""
                INSERT INTO "Users" ("Id", "Email", "PasswordHash", "Name", "TargetCefr", "CreatedAt")
                VALUES ({existingUserId}, {$"existing-{suffix}@example.com"}, {"hash"}, {"Existing"}, {"B2"}, {existingCreatedAt});
                """);

            await migrator.MigrateAsync();

            var backfilled = await ScalarAsync<DateTime?>(
                db,
                $"SELECT \"ProfileSetupCompletedAt\" FROM \"Users\" WHERE \"Id\" = '{existingUserId}'");
            Assert.Equal(existingCreatedAt, backfilled);

            var newUserId = Guid.NewGuid();
            await db.Database.ExecuteSqlInterpolatedAsync($"""
                INSERT INTO "Users" ("Id", "Email", "PasswordHash", "Name", "TargetCefr", "CreatedAt")
                VALUES ({newUserId}, {$"new-{suffix}@example.com"}, {"hash"}, {"New"}, {"B2"}, {DateTime.UtcNow});
                """);
            var newCompletion = await ScalarAsync<DateTime?>(
                db,
                $"SELECT \"ProfileSetupCompletedAt\" FROM \"Users\" WHERE \"Id\" = '{newUserId}'");
            Assert.Null(newCompletion);
        }
        finally
        {
            if (started)
            {
                await RunDocker("rm", "--force", containerName);
            }
        }
    }

    private static int ParsePublishedPort(string output)
    {
        var line = output.Trim().Split('\n', StringSplitOptions.RemoveEmptyEntries)[0];
        var separator = line.LastIndexOf(':');
        Assert.True(separator >= 0, $"Unexpected docker port output: {output}");
        return int.Parse(line[(separator + 1)..].Trim(), CultureInfo.InvariantCulture);
    }

    private static async Task<T?> ScalarAsync<T>(AppDbContext db, string sql)
    {
        await db.Database.OpenConnectionAsync();
        await using var command = db.Database.GetDbConnection().CreateCommand();
        command.CommandText = sql;
        var value = await command.ExecuteScalarAsync();
        return value is null or DBNull ? default : (T)value;
    }

    private static async Task<DockerResult> RunDocker(params string[] arguments)
    {
        using var process = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = "docker",
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true,
            },
        };
        foreach (var argument in arguments)
        {
            process.StartInfo.ArgumentList.Add(argument);
        }

        try
        {
            if (!process.Start())
            {
                return new DockerResult(false, -1, string.Empty, "docker did not start");
            }
        }
        catch (Win32Exception error)
        {
            return new DockerResult(false, -1, string.Empty, error.Message);
        }

        var standardOutput = process.StandardOutput.ReadToEndAsync();
        var standardError = process.StandardError.ReadToEndAsync();
        await process.WaitForExitAsync();
        return new DockerResult(
            true,
            process.ExitCode,
            await standardOutput,
            await standardError);
    }

    private sealed record DockerResult(
        bool Started,
        int ExitCode,
        string StandardOutput,
        string StandardError);

    private sealed class ExposedProfileSetupMigration : AddProfileSetupCompletion
    {
        public void Apply(MigrationBuilder builder) => Up(builder);
    }
}

public sealed class DockerAvailableFactAttribute : FactAttribute
{
    public DockerAvailableFactAttribute()
    {
        using var process = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = "docker",
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true,
            },
        };
        process.StartInfo.ArgumentList.Add("info");
        process.StartInfo.ArgumentList.Add("--format");
        process.StartInfo.ArgumentList.Add("{{.ServerVersion}}");

        try
        {
            if (!process.Start())
            {
                Skip = "Docker CLI did not start; disposable PostgreSQL is unavailable.";
                return;
            }
        }
        catch (Win32Exception)
        {
            Skip = "Docker CLI is not installed; disposable PostgreSQL is unavailable.";
            return;
        }

        if (!process.WaitForExit(5000))
        {
            process.Kill(entireProcessTree: true);
            Skip = "Docker availability check timed out; disposable PostgreSQL is unavailable.";
            return;
        }
        if (process.ExitCode != 0)
        {
            Skip = "Docker daemon is unavailable; disposable PostgreSQL is unavailable.";
        }
    }
}
