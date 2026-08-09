using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LingoRoad.Migrations
{
    /// <inheritdoc />
    public partial class AddSavedWordReviewSchedule : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "NextReviewAt",
                table: "SavedWords",
                type: "timestamp with time zone",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<int>(
                name: "ReviewStage",
                table: "SavedWords",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.CreateIndex(
                name: "IX_SavedWords_UserId_NextReviewAt",
                table: "SavedWords",
                columns: new[] { "UserId", "NextReviewAt" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_SavedWords_UserId_NextReviewAt",
                table: "SavedWords");

            migrationBuilder.DropColumn(
                name: "NextReviewAt",
                table: "SavedWords");

            migrationBuilder.DropColumn(
                name: "ReviewStage",
                table: "SavedWords");
        }
    }
}
