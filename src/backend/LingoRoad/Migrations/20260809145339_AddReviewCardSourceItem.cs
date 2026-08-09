using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LingoRoad.Migrations
{
    /// <inheritdoc />
    public partial class AddReviewCardSourceItem : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "SourceItemId",
                table: "ReviewCards",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_ReviewCards_UserId_SourceItemId",
                table: "ReviewCards",
                columns: new[] { "UserId", "SourceItemId" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_ReviewCards_UserId_SourceItemId",
                table: "ReviewCards");

            migrationBuilder.DropColumn(
                name: "SourceItemId",
                table: "ReviewCards");
        }
    }
}
