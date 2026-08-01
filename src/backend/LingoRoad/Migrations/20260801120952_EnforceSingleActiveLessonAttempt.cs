using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LingoRoad.Migrations
{
    /// <inheritdoc />
    public partial class EnforceSingleActiveLessonAttempt : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_LessonAttempts_UserId_LessonId_Status",
                table: "LessonAttempts");

            migrationBuilder.CreateIndex(
                name: "IX_LessonAttempts_UserId_LessonId_Status",
                table: "LessonAttempts",
                columns: new[] { "UserId", "LessonId", "Status" },
                unique: true,
                filter: "\"Status\" = 'in_progress'");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_LessonAttempts_UserId_LessonId_Status",
                table: "LessonAttempts");

            migrationBuilder.CreateIndex(
                name: "IX_LessonAttempts_UserId_LessonId_Status",
                table: "LessonAttempts",
                columns: new[] { "UserId", "LessonId", "Status" });
        }
    }
}
