using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace LingoRoad.Migrations
{
    /// <inheritdoc />
    public partial class AddDashboardGamification : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "RewardLedgerEntries",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    SourceOperationId = table.Column<Guid>(type: "uuid", nullable: false),
                    SourceType = table.Column<string>(type: "text", nullable: false),
                    SourceEntityId = table.Column<Guid>(type: "uuid", nullable: false),
                    Xp = table.Column<int>(type: "integer", nullable: false),
                    Coins = table.Column<int>(type: "integer", nullable: false),
                    StreakQualified = table.Column<bool>(type: "boolean", nullable: false),
                    QuestCode = table.Column<string>(type: "text", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RewardLedgerEntries", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RewardLedgerEntries_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_RewardLedgerEntries_UserId_CreatedAt",
                table: "RewardLedgerEntries",
                columns: new[] { "UserId", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_RewardLedgerEntries_UserId_SourceOperationId",
                table: "RewardLedgerEntries",
                columns: new[] { "UserId", "SourceOperationId" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "RewardLedgerEntries");
        }
    }
}
