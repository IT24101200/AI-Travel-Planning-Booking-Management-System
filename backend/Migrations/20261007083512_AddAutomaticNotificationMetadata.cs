using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace backend.Migrations
{
    /// <inheritdoc />
    public partial class AddAutomaticNotificationMetadata : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "EventKey",
                table: "Notifications",
                type: "character varying(200)",
                maxLength: 200,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ReferenceId",
                table: "Notifications",
                type: "character varying(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ReferenceType",
                table: "Notifications",
                type: "character varying(50)",
                maxLength: 50,
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Notifications_EventKey",
                table: "Notifications",
                column: "EventKey",
                unique: true,
                filter: "\"EventKey\" IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Notifications_EventKey",
                table: "Notifications");

            migrationBuilder.DropColumn(
                name: "EventKey",
                table: "Notifications");

            migrationBuilder.DropColumn(
                name: "ReferenceId",
                table: "Notifications");

            migrationBuilder.DropColumn(
                name: "ReferenceType",
                table: "Notifications");
        }
    }
}
