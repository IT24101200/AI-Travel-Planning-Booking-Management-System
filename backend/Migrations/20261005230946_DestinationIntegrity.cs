using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace backend.Migrations
{
    /// <inheritdoc />
    public partial class DestinationIntegrity : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "NormalizedName",
                table: "Destinations",
                type: "character varying(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.Sql(@"
                UPDATE ""Destinations""
                SET ""NormalizedName"" = UPPER(BTRIM(""Name""));

                DO $$
                BEGIN
                    IF EXISTS (
                        SELECT 1
                        FROM ""Destinations""
                        GROUP BY ""NormalizedName""
                        HAVING COUNT(*) > 1
                    ) THEN
                        RAISE EXCEPTION 'Duplicate destination names must be resolved before applying DestinationIntegrity.';
                    END IF;
                END $$;
            ");

            migrationBuilder.AlterColumn<string>(
                name: "NormalizedName",
                table: "Destinations",
                type: "character varying(100)",
                maxLength: 100,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(100)",
                oldMaxLength: 100,
                oldNullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Destinations_NormalizedName",
                table: "Destinations",
                column: "NormalizedName",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Destinations_NormalizedName",
                table: "Destinations");

            migrationBuilder.DropColumn(
                name: "NormalizedName",
                table: "Destinations");
        }
    }
}
