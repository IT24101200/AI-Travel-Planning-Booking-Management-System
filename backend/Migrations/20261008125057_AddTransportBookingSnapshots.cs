using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace backend.Migrations
{
    /// <inheritdoc />
    public partial class AddTransportBookingSnapshots : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "TransportArrivalTimeSnapshot",
                table: "BookingItems",
                type: "timestamp without time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "TransportDepartureTimeSnapshot",
                table: "BookingItems",
                type: "timestamp without time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "TransportProviderSnapshot",
                table: "BookingItems",
                type: "character varying(150)",
                maxLength: 150,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "TransportRouteFromSnapshot",
                table: "BookingItems",
                type: "character varying(200)",
                maxLength: 200,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "TransportRouteToSnapshot",
                table: "BookingItems",
                type: "character varying(200)",
                maxLength: 200,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "TransportTypeSnapshot",
                table: "BookingItems",
                type: "character varying(20)",
                maxLength: 20,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "TransportArrivalTimeSnapshot",
                table: "BookingItems");

            migrationBuilder.DropColumn(
                name: "TransportDepartureTimeSnapshot",
                table: "BookingItems");

            migrationBuilder.DropColumn(
                name: "TransportProviderSnapshot",
                table: "BookingItems");

            migrationBuilder.DropColumn(
                name: "TransportRouteFromSnapshot",
                table: "BookingItems");

            migrationBuilder.DropColumn(
                name: "TransportRouteToSnapshot",
                table: "BookingItems");

            migrationBuilder.DropColumn(
                name: "TransportTypeSnapshot",
                table: "BookingItems");
        }
    }
}
