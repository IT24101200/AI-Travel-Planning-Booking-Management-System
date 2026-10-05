using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace backend.Migrations
{
    /// <inheritdoc />
    public partial class AddCurrencyPreferenceSupport : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<string>(
                name: "Currency",
                table: "TripRequests",
                type: "character varying(10)",
                maxLength: 10,
                nullable: false,
                defaultValue: "LKR",
                oldClrType: typeof(string),
                oldType: "character varying(10)",
                oldMaxLength: 10,
                oldDefaultValue: "USD");

            migrationBuilder.AlterColumn<string>(
                name: "Currency",
                table: "TransportOptions",
                type: "character varying(10)",
                maxLength: 10,
                nullable: false,
                defaultValue: "LKR",
                oldClrType: typeof(string),
                oldType: "character varying(10)",
                oldMaxLength: 10,
                oldDefaultValue: "USD");

            migrationBuilder.AlterColumn<string>(
                name: "Currency",
                table: "Rooms",
                type: "character varying(10)",
                maxLength: 10,
                nullable: false,
                defaultValue: "LKR",
                oldClrType: typeof(string),
                oldType: "character varying(10)",
                oldMaxLength: 10,
                oldDefaultValue: "USD");

            migrationBuilder.AlterColumn<string>(
                name: "Currency",
                table: "Preferences",
                type: "character varying(10)",
                maxLength: 10,
                nullable: false,
                defaultValue: "LKR",
                oldClrType: typeof(string),
                oldType: "character varying(10)",
                oldMaxLength: 10,
                oldDefaultValue: "USD");

            migrationBuilder.AlterColumn<string>(
                name: "Currency",
                table: "Payments",
                type: "character varying(10)",
                maxLength: 10,
                nullable: false,
                defaultValue: "LKR",
                oldClrType: typeof(string),
                oldType: "character varying(10)",
                oldMaxLength: 10,
                oldDefaultValue: "USD");

            migrationBuilder.AddColumn<decimal>(
                name: "ExchangeRateToLkr",
                table: "Payments",
                type: "numeric(18,6)",
                nullable: false,
                defaultValue: 1m);

            migrationBuilder.AddColumn<string>(
                name: "Currency",
                table: "ItineraryItems",
                type: "character varying(3)",
                maxLength: 3,
                nullable: false,
                defaultValue: "LKR");

            migrationBuilder.AlterColumn<string>(
                name: "Currency",
                table: "Itineraries",
                type: "character varying(10)",
                maxLength: 10,
                nullable: false,
                defaultValue: "LKR",
                oldClrType: typeof(string),
                oldType: "character varying(10)",
                oldMaxLength: 10,
                oldDefaultValue: "USD");

            migrationBuilder.AddColumn<decimal>(
                name: "ExchangeRateToLkr",
                table: "Itineraries",
                type: "numeric(18,6)",
                nullable: false,
                defaultValue: 1m);

            migrationBuilder.AlterColumn<string>(
                name: "Currency",
                table: "Bookings",
                type: "character varying(10)",
                maxLength: 10,
                nullable: false,
                defaultValue: "LKR",
                oldClrType: typeof(string),
                oldType: "character varying(10)",
                oldMaxLength: 10,
                oldDefaultValue: "USD");

            migrationBuilder.AddColumn<decimal>(
                name: "ExchangeRateToLkr",
                table: "Bookings",
                type: "numeric(18,6)",
                nullable: false,
                defaultValue: 1m);

            migrationBuilder.AddColumn<string>(
                name: "Currency",
                table: "BookingItems",
                type: "character varying(3)",
                maxLength: 3,
                nullable: false,
                defaultValue: "LKR");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ExchangeRateToLkr",
                table: "Payments");

            migrationBuilder.DropColumn(
                name: "Currency",
                table: "ItineraryItems");

            migrationBuilder.DropColumn(
                name: "ExchangeRateToLkr",
                table: "Itineraries");

            migrationBuilder.DropColumn(
                name: "ExchangeRateToLkr",
                table: "Bookings");

            migrationBuilder.DropColumn(
                name: "Currency",
                table: "BookingItems");

            migrationBuilder.AlterColumn<string>(
                name: "Currency",
                table: "TripRequests",
                type: "character varying(10)",
                maxLength: 10,
                nullable: false,
                defaultValue: "USD",
                oldClrType: typeof(string),
                oldType: "character varying(10)",
                oldMaxLength: 10,
                oldDefaultValue: "LKR");

            migrationBuilder.AlterColumn<string>(
                name: "Currency",
                table: "TransportOptions",
                type: "character varying(10)",
                maxLength: 10,
                nullable: false,
                defaultValue: "USD",
                oldClrType: typeof(string),
                oldType: "character varying(10)",
                oldMaxLength: 10,
                oldDefaultValue: "LKR");

            migrationBuilder.AlterColumn<string>(
                name: "Currency",
                table: "Rooms",
                type: "character varying(10)",
                maxLength: 10,
                nullable: false,
                defaultValue: "USD",
                oldClrType: typeof(string),
                oldType: "character varying(10)",
                oldMaxLength: 10,
                oldDefaultValue: "LKR");

            migrationBuilder.AlterColumn<string>(
                name: "Currency",
                table: "Preferences",
                type: "character varying(10)",
                maxLength: 10,
                nullable: false,
                defaultValue: "USD",
                oldClrType: typeof(string),
                oldType: "character varying(10)",
                oldMaxLength: 10,
                oldDefaultValue: "LKR");

            migrationBuilder.AlterColumn<string>(
                name: "Currency",
                table: "Payments",
                type: "character varying(10)",
                maxLength: 10,
                nullable: false,
                defaultValue: "USD",
                oldClrType: typeof(string),
                oldType: "character varying(10)",
                oldMaxLength: 10,
                oldDefaultValue: "LKR");

            migrationBuilder.AlterColumn<string>(
                name: "Currency",
                table: "Itineraries",
                type: "character varying(10)",
                maxLength: 10,
                nullable: false,
                defaultValue: "USD",
                oldClrType: typeof(string),
                oldType: "character varying(10)",
                oldMaxLength: 10,
                oldDefaultValue: "LKR");

            migrationBuilder.AlterColumn<string>(
                name: "Currency",
                table: "Bookings",
                type: "character varying(10)",
                maxLength: 10,
                nullable: false,
                defaultValue: "USD",
                oldClrType: typeof(string),
                oldType: "character varying(10)",
                oldMaxLength: 10,
                oldDefaultValue: "LKR");
        }
    }
}
