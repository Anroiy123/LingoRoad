using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LingoRoad.Migrations
{
    /// <inheritdoc />
    public partial class HardenPlacementIntegrity : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "CurrentItemId",
                table: "TestSessions",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "CompletedAfter",
                table: "Responses",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<Guid>(
                name: "NextItemId",
                table: "Responses",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ResultCefrAfter",
                table: "Responses",
                type: "text",
                nullable: true);

            migrationBuilder.Sql(
                """
                DO $migration$
                BEGIN
                    IF EXISTS (
                        SELECT 1
                        FROM "Users"
                        GROUP BY lower(trim("Email"))
                        HAVING COUNT(*) > 1
                    ) THEN
                        RAISE EXCEPTION
                            'Cannot canonicalize Users.Email because normalized duplicates exist';
                    END IF;

                    IF EXISTS (
                        SELECT 1
                        FROM "Responses"
                        GROUP BY "SessionId", "ItemId"
                        HAVING COUNT(*) > 1
                    ) THEN
                        RAISE EXCEPTION
                            'Cannot enforce placement idempotency because duplicate responses exist';
                    END IF;
                END
                $migration$;

                UPDATE "Users"
                SET "Email" = lower(trim("Email"))
                WHERE "Email" <> lower(trim("Email"));
                """);

            migrationBuilder.AddCheckConstraint(
                name: "CK_Users_Email_Canonical",
                table: "Users",
                sql: "\"Email\" = lower(trim(\"Email\"))");

            migrationBuilder.CreateIndex(
                name: "IX_TestSessions_CurrentItemId",
                table: "TestSessions",
                column: "CurrentItemId");

            migrationBuilder.CreateIndex(
                name: "IX_Responses_SessionId_ItemId",
                table: "Responses",
                columns: new[] { "SessionId", "ItemId" },
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_TestSessions_Items_CurrentItemId",
                table: "TestSessions",
                column: "CurrentItemId",
                principalTable: "Items",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_TestSessions_Items_CurrentItemId",
                table: "TestSessions");

            migrationBuilder.DropCheckConstraint(
                name: "CK_Users_Email_Canonical",
                table: "Users");

            migrationBuilder.DropIndex(
                name: "IX_TestSessions_CurrentItemId",
                table: "TestSessions");

            migrationBuilder.DropIndex(
                name: "IX_Responses_SessionId_ItemId",
                table: "Responses");

            migrationBuilder.DropColumn(
                name: "CurrentItemId",
                table: "TestSessions");

            migrationBuilder.DropColumn(
                name: "CompletedAfter",
                table: "Responses");

            migrationBuilder.DropColumn(
                name: "NextItemId",
                table: "Responses");

            migrationBuilder.DropColumn(
                name: "ResultCefrAfter",
                table: "Responses");
        }
    }
}
