using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LingoRoad.Migrations
{
    /// <inheritdoc />
    public partial class AddProfileSetupCompletion : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "ProfileSetupCompletedAt",
                table: "Users",
                type: "timestamp with time zone",
                nullable: true);
            migrationBuilder.Sql("UPDATE \"Users\" SET \"ProfileSetupCompletedAt\" = \"CreatedAt\" WHERE \"ProfileSetupCompletedAt\" IS NULL;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ProfileSetupCompletedAt",
                table: "Users");
        }
    }
}
