using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LingoRoad.Migrations
{
    /// <inheritdoc />
    public partial class AddQuestionReviewGradeAnswers : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "Correct",
                table: "ReviewGradeOperations",
                type: "boolean",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "SubmittedAnswer",
                table: "ReviewGradeOperations",
                type: "text",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Correct",
                table: "ReviewGradeOperations");

            migrationBuilder.DropColumn(
                name: "SubmittedAnswer",
                table: "ReviewGradeOperations");
        }
    }
}
