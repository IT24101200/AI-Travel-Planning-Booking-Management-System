using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace backend.Migrations
{
    /// <inheritdoc />
    public partial class AddTransportLegIndex : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "TransportLegIndex",
                table: "BookingItems",
                type: "integer",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_BookingItems_BookingId_TransportLegIndex",
                table: "BookingItems",
                columns: new[] { "BookingId", "TransportLegIndex" },
                unique: true,
                filter: "\"TransportLegIndex\" IS NOT NULL AND \"ItemType\" = 'Transport'");

            migrationBuilder.AddCheckConstraint(
                name: "CK_BookingItems_TransportLegIndex",
                table: "BookingItems",
                sql: "\"TransportLegIndex\" IS NULL OR (\"ItemType\" = 'Transport' AND \"TransportLegIndex\" >= 0)");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_BookingItems_BookingId_TransportLegIndex",
                table: "BookingItems");

            migrationBuilder.DropCheckConstraint(
                name: "CK_BookingItems_TransportLegIndex",
                table: "BookingItems");

            migrationBuilder.DropColumn(
                name: "TransportLegIndex",
                table: "BookingItems");
        }
    }
}
