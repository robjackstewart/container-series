using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using OrderApi.Data;
using OrderApi.Models;
using OrderApi.Services;
using OrderApi.Tests.Infrastructure;

namespace OrderApi.Tests;

public sealed class DatabaseTests(PostgresFixture fixture) : IClassFixture<PostgresFixture>
{
    [Fact]
    public async Task CanCreateOrder_InDatabase()
    {
        await using var dbContext = CreateDbContext();
        var service = new OrderService(dbContext);

        var order = await service.CreateOrderAsync(new Order
        {
            CustomerName = $"Customer-{Guid.NewGuid():N}",
            Product = "Mechanical Keyboard",
            Quantity = 2,
            TotalPrice = 249.99m,
            Status = "Pending"
        });

        var persistedOrder = await dbContext.Orders.AsNoTracking().SingleAsync(x => x.Id == order.Id);

        persistedOrder.CustomerName.Should().Be(order.CustomerName);
        persistedOrder.Product.Should().Be("Mechanical Keyboard");
    }

    [Fact]
    public async Task CanGetOrder_FromDatabase()
    {
        await using var dbContext = CreateDbContext();
        var service = new OrderService(dbContext);

        var createdOrder = await service.CreateOrderAsync(new Order
        {
            CustomerName = $"Customer-{Guid.NewGuid():N}",
            Product = "Mouse",
            Quantity = 1,
            TotalPrice = 59.99m,
            Status = "Processing"
        });

        var loadedOrder = await service.GetOrderAsync(createdOrder.Id);

        loadedOrder.Should().NotBeNull();
        loadedOrder!.Id.Should().Be(createdOrder.Id);
        loadedOrder.Product.Should().Be("Mouse");
    }

    [Fact]
    public async Task CanDeleteOrder_FromDatabase()
    {
        await using var dbContext = CreateDbContext();
        var service = new OrderService(dbContext);

        var createdOrder = await service.CreateOrderAsync(new Order
        {
            CustomerName = $"Customer-{Guid.NewGuid():N}",
            Product = "Headset",
            Quantity = 1,
            TotalPrice = 129.99m,
            Status = "Pending"
        });

        var deleted = await service.DeleteOrderAsync(createdOrder.Id);
        var deletedOrder = await service.GetOrderAsync(createdOrder.Id);

        deleted.Should().BeTrue();
        deletedOrder.Should().BeNull();
    }

    [Fact]
    public async Task ReturnsNotFound_WhenOrderDoesNotExist()
    {
        await using var dbContext = CreateDbContext();
        var service = new OrderService(dbContext);

        var missingOrder = await service.GetOrderAsync(Guid.NewGuid());

        missingOrder.Should().BeNull();
    }

    private AppDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseNpgsql(fixture.ConnectionString)
            .Options;

        return new AppDbContext(options);
    }
}
