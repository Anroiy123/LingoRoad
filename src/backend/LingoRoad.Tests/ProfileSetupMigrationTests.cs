using LingoRoad.Migrations;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.EntityFrameworkCore.Migrations.Operations;

namespace LingoRoad.Tests;

public class ProfileSetupMigrationTests
{
    [Fact]
    public void Existing_users_are_backfilled_while_new_rows_keep_nullable_completion_column()
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

    private sealed class ExposedProfileSetupMigration : AddProfileSetupCompletion
    {
        public void Apply(MigrationBuilder builder) => Up(builder);
    }
}
