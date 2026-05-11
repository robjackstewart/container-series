using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace OrderApi.Migrations;

public partial class InitialCreate : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "Orders",
            columns: table => new
            {
                Id = table.Column<Guid>(type: "uuid", nullable: false),
                CustomerName = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                Product = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                Quantity = table.Column<int>(type: "integer", nullable: false),
                TotalPrice = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                Status = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_Orders", x => x.Id);
            });
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "Orders");
    }
}
