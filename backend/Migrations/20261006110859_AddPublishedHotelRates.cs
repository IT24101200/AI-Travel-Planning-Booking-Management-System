using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace backend.Migrations
{
    /// <inheritdoc />
    public partial class AddPublishedHotelRates : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            if (ActiveProvider.Contains("Npgsql"))
            {
                // The audited catalog SQL can run before this application deploys.
                migrationBuilder.Sql("ALTER TABLE \"Rooms\" ADD COLUMN IF NOT EXISTS \"RateNotes\" character varying(1000);");
                migrationBuilder.Sql("ALTER TABLE \"Rooms\" ADD COLUMN IF NOT EXISTS \"RateSourceUrl\" character varying(500);");
            }
            else
            {
                migrationBuilder.AddColumn<string>(name: "RateNotes", table: "Rooms", type: "character varying(1000)", maxLength: 1000, nullable: true);
                migrationBuilder.AddColumn<string>(name: "RateSourceUrl", table: "Rooms", type: "character varying(500)", maxLength: 500, nullable: true);
            }
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "RateNotes",
                table: "Rooms");

            migrationBuilder.DropColumn(
                name: "RateSourceUrl",
                table: "Rooms");
        }
    }
}
