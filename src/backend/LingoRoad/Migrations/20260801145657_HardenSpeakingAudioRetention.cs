using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LingoRoad.Migrations
{
    /// <inheritdoc />
    public partial class HardenSpeakingAudioRetention : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "AudioPath",
                table: "SpeakingAttempts");

            migrationBuilder.AddColumn<double>(
                name: "DurationSeconds",
                table: "SpeakingAttempts",
                type: "double precision",
                nullable: false,
                defaultValue: 0.0);

            migrationBuilder.AddColumn<string>(
                name: "FeedbackVi",
                table: "SpeakingAttempts",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ModelVersion",
                table: "SpeakingAttempts",
                type: "text",
                nullable: false,
                defaultValue: "legacy-unknown");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "DurationSeconds",
                table: "SpeakingAttempts");

            migrationBuilder.DropColumn(
                name: "FeedbackVi",
                table: "SpeakingAttempts");

            migrationBuilder.DropColumn(
                name: "ModelVersion",
                table: "SpeakingAttempts");

            migrationBuilder.AddColumn<string>(
                name: "AudioPath",
                table: "SpeakingAttempts",
                type: "text",
                nullable: false,
                defaultValue: "");
        }
    }
}
