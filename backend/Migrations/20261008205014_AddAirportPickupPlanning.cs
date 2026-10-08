using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace backend.Migrations
{
    /// <inheritdoc />
    public partial class AddAirportPickupPlanning : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<TimeSpan>(
                name: "AirportArrivalTime",
                table: "TripRequests",
                type: "interval",
                nullable: false,
                defaultValue: TimeSpan.FromHours(8));

            migrationBuilder.AddColumn<string>(
                name: "AirportCode",
                table: "TripRequests",
                type: "character varying(3)",
                maxLength: 3,
                nullable: false,
                defaultValue: "CMB");

            migrationBuilder.AddColumn<bool>(
                name: "AirportPickup",
                table: "TripRequests",
                type: "boolean",
                nullable: false,
                defaultValue: false);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "AirportArrivalTime",
                table: "TripRequests");

            migrationBuilder.DropColumn(
                name: "AirportCode",
                table: "TripRequests");

            migrationBuilder.DropColumn(
                name: "AirportPickup",
                table: "TripRequests");
        }
    }
}
