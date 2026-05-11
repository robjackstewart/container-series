using System;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;
using OrderApi.Data;

#nullable disable

namespace OrderApi.Migrations;

[DbContext(typeof(AppDbContext))]
partial class AppDbContextModelSnapshot : ModelSnapshot
{
    protected override void BuildModel(ModelBuilder modelBuilder)
    {
#pragma warning disable 612, 618
        modelBuilder
            .HasAnnotation("ProductVersion", "8.0.0")
            .HasAnnotation("Relational:MaxIdentifierLength", 63);

        NpgsqlModelBuilderExtensions.UseIdentityByDefaultColumns(modelBuilder);

        modelBuilder.Entity("OrderApi.Models.Order", b =>
        {
            b.Property<Guid>("Id")
                .ValueGeneratedNever()
                .HasColumnType("uuid");

            b.Property<DateTime>("CreatedAt")
                .HasColumnType("timestamp with time zone");

            b.Property<string>("CustomerName")
                .IsRequired()
                .HasMaxLength(200)
                .HasColumnType("character varying(200)");

            b.Property<string>("Product")
                .IsRequired()
                .HasMaxLength(200)
                .HasColumnType("character varying(200)");

            b.Property<int>("Quantity")
                .HasColumnType("integer");

            b.Property<string>("Status")
                .IsRequired()
                .HasMaxLength(50)
                .HasColumnType("character varying(50)");

            b.Property<decimal>("TotalPrice")
                .HasPrecision(18, 2)
                .HasColumnType("numeric(18,2)");

            b.HasKey("Id");

            b.ToTable("Orders");
        });
#pragma warning restore 612, 618
    }
}
