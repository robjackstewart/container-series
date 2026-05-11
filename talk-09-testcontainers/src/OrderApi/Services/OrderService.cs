using Microsoft.EntityFrameworkCore;
using OrderApi.Data;
using OrderApi.Models;

namespace OrderApi.Services;

public interface IOrderService
{
    Task<IReadOnlyList<Order>> GetOrdersAsync(CancellationToken cancellationToken = default);
    Task<Order?> GetOrderAsync(Guid id, CancellationToken cancellationToken = default);
    Task<Order> CreateOrderAsync(Order order, CancellationToken cancellationToken = default);
    Task<bool> DeleteOrderAsync(Guid id, CancellationToken cancellationToken = default);
}

public sealed class OrderService(AppDbContext dbContext) : IOrderService
{
    public async Task<IReadOnlyList<Order>> GetOrdersAsync(CancellationToken cancellationToken = default)
    {
        return await dbContext.Orders
            .AsNoTracking()
            .OrderByDescending(x => x.CreatedAt)
            .ToListAsync(cancellationToken);
    }

    public async Task<Order?> GetOrderAsync(Guid id, CancellationToken cancellationToken = default)
    {
        return await dbContext.Orders
            .AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == id, cancellationToken);
    }

    public async Task<Order> CreateOrderAsync(Order order, CancellationToken cancellationToken = default)
    {
        order.Id = order.Id == Guid.Empty ? Guid.NewGuid() : order.Id;
        order.CreatedAt = order.CreatedAt == default ? DateTime.UtcNow : order.CreatedAt;

        dbContext.Orders.Add(order);
        await dbContext.SaveChangesAsync(cancellationToken);

        return order;
    }

    public async Task<bool> DeleteOrderAsync(Guid id, CancellationToken cancellationToken = default)
    {
        var order = await dbContext.Orders.SingleOrDefaultAsync(x => x.Id == id, cancellationToken);
        if (order is null)
        {
            return false;
        }

        dbContext.Orders.Remove(order);
        await dbContext.SaveChangesAsync(cancellationToken);
        return true;
    }
}
