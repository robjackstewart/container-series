using Microsoft.EntityFrameworkCore;
using OrderApi.Models;

namespace OrderApi.Data;

public sealed class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<Order> Orders => Set<Order>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        var order = modelBuilder.Entity<Order>();

        order.HasKey(x => x.Id);
        order.Property(x => x.CustomerName).HasMaxLength(200).IsRequired();
        order.Property(x => x.Product).HasMaxLength(200).IsRequired();
        order.Property(x => x.Quantity).IsRequired();
        order.Property(x => x.TotalPrice).HasPrecision(18, 2).IsRequired();
        order.Property(x => x.Status).HasMaxLength(50).IsRequired();
        order.Property(x => x.CreatedAt).IsRequired();
    }
}
