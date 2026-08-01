using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace LingoRoad.Migrations
{
    /// <inheritdoc />
    public partial class AddLessonContentLoop : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "SourceExerciseId",
                table: "ReviewCards",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ContentVersion",
                table: "Items",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ExplanationVi",
                table: "Items",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "License",
                table: "Items",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Reviewer",
                table: "Items",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "StableId",
                table: "Items",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsCorrect",
                table: "Exercises",
                type: "boolean",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "LessonAttemptId",
                table: "Exercises",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "Sequence",
                table: "Exercises",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<Guid>(
                name: "SourceItemId",
                table: "Exercises",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "SubmittedAnswer",
                table: "Exercises",
                type: "text",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "ContentBundleImports",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    Version = table.Column<string>(type: "text", nullable: false),
                    Checksum = table.Column<string>(type: "text", nullable: false),
                    AppliedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ContentBundleImports", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "ExerciseAnswerOperations",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    OperationId = table.Column<Guid>(type: "uuid", nullable: false),
                    ExerciseId = table.Column<Guid>(type: "uuid", nullable: false),
                    Answer = table.Column<string>(type: "text", nullable: false),
                    Correct = table.Column<bool>(type: "boolean", nullable: false),
                    CorrectAnswer = table.Column<string>(type: "text", nullable: false),
                    ExplanationVi = table.Column<string>(type: "text", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ExerciseAnswerOperations", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "LessonCompletionOperations",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    OperationId = table.Column<Guid>(type: "uuid", nullable: false),
                    AttemptId = table.Column<Guid>(type: "uuid", nullable: false),
                    CorrectAnswers = table.Column<int>(type: "integer", nullable: false),
                    TotalAnswers = table.Column<int>(type: "integer", nullable: false),
                    ReviewCardsCreated = table.Column<int>(type: "integer", nullable: false),
                    CompletedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_LessonCompletionOperations", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Lessons",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    StableId = table.Column<string>(type: "text", nullable: false),
                    Slug = table.Column<string>(type: "text", nullable: false),
                    Title = table.Column<string>(type: "text", nullable: false),
                    TitleVi = table.Column<string>(type: "text", nullable: false),
                    DescriptionVi = table.Column<string>(type: "text", nullable: true),
                    SkillId = table.Column<int>(type: "integer", nullable: false),
                    CefrLevel = table.Column<string>(type: "text", nullable: false),
                    Order = table.Column<int>(type: "integer", nullable: false),
                    ContentVersion = table.Column<string>(type: "text", nullable: false),
                    ContentChecksum = table.Column<string>(type: "text", nullable: false),
                    Source = table.Column<string>(type: "text", nullable: false),
                    License = table.Column<string>(type: "text", nullable: false),
                    Reviewer = table.Column<string>(type: "text", nullable: false),
                    IsPublished = table.Column<bool>(type: "boolean", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Lessons", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Lessons_Skills_SkillId",
                        column: x => x.SkillId,
                        principalTable: "Skills",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "LessonAttempts",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    LessonId = table.Column<Guid>(type: "uuid", nullable: false),
                    StartOperationId = table.Column<Guid>(type: "uuid", nullable: false),
                    Status = table.Column<string>(type: "text", nullable: false),
                    StartedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CompletedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_LessonAttempts", x => x.Id);
                    table.ForeignKey(
                        name: "FK_LessonAttempts_Lessons_LessonId",
                        column: x => x.LessonId,
                        principalTable: "Lessons",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_LessonAttempts_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "LessonItems",
                columns: table => new
                {
                    LessonId = table.Column<Guid>(type: "uuid", nullable: false),
                    ItemId = table.Column<Guid>(type: "uuid", nullable: false),
                    Order = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_LessonItems", x => new { x.LessonId, x.ItemId });
                    table.ForeignKey(
                        name: "FK_LessonItems_Items_ItemId",
                        column: x => x.ItemId,
                        principalTable: "Items",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_LessonItems_Lessons_LessonId",
                        column: x => x.LessonId,
                        principalTable: "Lessons",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "UserLessonProgresses",
                columns: table => new
                {
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    LessonId = table.Column<Guid>(type: "uuid", nullable: false),
                    CompletionCount = table.Column<int>(type: "integer", nullable: false),
                    CorrectAnswers = table.Column<int>(type: "integer", nullable: false),
                    TotalAnswers = table.Column<int>(type: "integer", nullable: false),
                    LastCompletedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserLessonProgresses", x => new { x.UserId, x.LessonId });
                    table.ForeignKey(
                        name: "FK_UserLessonProgresses_Lessons_LessonId",
                        column: x => x.LessonId,
                        principalTable: "Lessons",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_UserLessonProgresses_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ReviewCards_SourceExerciseId",
                table: "ReviewCards",
                column: "SourceExerciseId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Items_StableId",
                table: "Items",
                column: "StableId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Exercises_LessonAttemptId_Sequence",
                table: "Exercises",
                columns: new[] { "LessonAttemptId", "Sequence" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Exercises_LessonAttemptId_SourceItemId",
                table: "Exercises",
                columns: new[] { "LessonAttemptId", "SourceItemId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Exercises_SourceItemId",
                table: "Exercises",
                column: "SourceItemId");

            migrationBuilder.CreateIndex(
                name: "IX_ContentBundleImports_Version",
                table: "ContentBundleImports",
                column: "Version",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ExerciseAnswerOperations_UserId_OperationId",
                table: "ExerciseAnswerOperations",
                columns: new[] { "UserId", "OperationId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_LessonAttempts_LessonId",
                table: "LessonAttempts",
                column: "LessonId");

            migrationBuilder.CreateIndex(
                name: "IX_LessonAttempts_UserId_LessonId_Status",
                table: "LessonAttempts",
                columns: new[] { "UserId", "LessonId", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_LessonAttempts_UserId_StartOperationId",
                table: "LessonAttempts",
                columns: new[] { "UserId", "StartOperationId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_LessonCompletionOperations_UserId_OperationId",
                table: "LessonCompletionOperations",
                columns: new[] { "UserId", "OperationId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_LessonItems_ItemId",
                table: "LessonItems",
                column: "ItemId");

            migrationBuilder.CreateIndex(
                name: "IX_LessonItems_LessonId_Order",
                table: "LessonItems",
                columns: new[] { "LessonId", "Order" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Lessons_SkillId_Order",
                table: "Lessons",
                columns: new[] { "SkillId", "Order" });

            migrationBuilder.CreateIndex(
                name: "IX_Lessons_Slug",
                table: "Lessons",
                column: "Slug",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Lessons_StableId",
                table: "Lessons",
                column: "StableId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_UserLessonProgresses_LessonId",
                table: "UserLessonProgresses",
                column: "LessonId");

            migrationBuilder.AddForeignKey(
                name: "FK_Exercises_Items_SourceItemId",
                table: "Exercises",
                column: "SourceItemId",
                principalTable: "Items",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_Exercises_LessonAttempts_LessonAttemptId",
                table: "Exercises",
                column: "LessonAttemptId",
                principalTable: "LessonAttempts",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Exercises_Items_SourceItemId",
                table: "Exercises");

            migrationBuilder.DropForeignKey(
                name: "FK_Exercises_LessonAttempts_LessonAttemptId",
                table: "Exercises");

            migrationBuilder.DropTable(
                name: "ContentBundleImports");

            migrationBuilder.DropTable(
                name: "ExerciseAnswerOperations");

            migrationBuilder.DropTable(
                name: "LessonAttempts");

            migrationBuilder.DropTable(
                name: "LessonCompletionOperations");

            migrationBuilder.DropTable(
                name: "LessonItems");

            migrationBuilder.DropTable(
                name: "UserLessonProgresses");

            migrationBuilder.DropTable(
                name: "Lessons");

            migrationBuilder.DropIndex(
                name: "IX_ReviewCards_SourceExerciseId",
                table: "ReviewCards");

            migrationBuilder.DropIndex(
                name: "IX_Items_StableId",
                table: "Items");

            migrationBuilder.DropIndex(
                name: "IX_Exercises_LessonAttemptId_Sequence",
                table: "Exercises");

            migrationBuilder.DropIndex(
                name: "IX_Exercises_LessonAttemptId_SourceItemId",
                table: "Exercises");

            migrationBuilder.DropIndex(
                name: "IX_Exercises_SourceItemId",
                table: "Exercises");

            migrationBuilder.DropColumn(
                name: "SourceExerciseId",
                table: "ReviewCards");

            migrationBuilder.DropColumn(
                name: "ContentVersion",
                table: "Items");

            migrationBuilder.DropColumn(
                name: "ExplanationVi",
                table: "Items");

            migrationBuilder.DropColumn(
                name: "License",
                table: "Items");

            migrationBuilder.DropColumn(
                name: "Reviewer",
                table: "Items");

            migrationBuilder.DropColumn(
                name: "StableId",
                table: "Items");

            migrationBuilder.DropColumn(
                name: "IsCorrect",
                table: "Exercises");

            migrationBuilder.DropColumn(
                name: "LessonAttemptId",
                table: "Exercises");

            migrationBuilder.DropColumn(
                name: "Sequence",
                table: "Exercises");

            migrationBuilder.DropColumn(
                name: "SourceItemId",
                table: "Exercises");

            migrationBuilder.DropColumn(
                name: "SubmittedAnswer",
                table: "Exercises");
        }
    }
}
