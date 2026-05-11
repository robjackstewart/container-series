using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.EntityFrameworkCore;

namespace ContainerSeries.OrderService;

public static class OrderEndpoints
{
    public static IEndpointRouteBuilder MapOrderEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/orders");

        group.MapGet("/", GetOrdersAsync);
        group.MapGet("/{id:int}", GetOrderByIdAsync);
        group.MapPost("/", CreateOrderAsync);

        return app;
    }

    private static async Task<Ok<List<Order>>> GetOrdersAsync(OrderDbContext dbContext, CancellationToken cancellationToken)
    {
        var orders = await dbContext.Orders
            .OrderByDescending(order => order.CreatedAtUtc)
            .ToListAsync(cancellationToken);

        return TypedResults.Ok(orders);
    }

    private static async Task<Results<Ok<Order>, NotFound>> GetOrderByIdAsync(int id, OrderDbContext dbContext, CancellationToken cancellationToken)
    {
        var order = await dbContext.Orders.FirstOrDefaultAsync(existing => existing.Id == id, cancellationToken);
        return order is null ? TypedResults.NotFound() : TypedResults.Ok(order);
    }

    private static async Task<Created<Order>> CreateOrderAsync(CreateOrderRequest request, OrderDbContext dbContext, IOrderPublisher orderPublisher, CancellationToken cancellationToken)
    {
        var order = new Order
        {
            CustomerName = request.CustomerName,
            ProductName = request.ProductName,
            Quantity = request.Quantity,
            CreatedAtUtc = DateTimeOffset.UtcNow,
            Status = "Created"
        };

        dbContext.Orders.Add(order);
        await dbContext.SaveChangesAsync(cancellationToken);
        await orderPublisher.PublishOrderCreatedAsync(order, cancellationToken);

        return TypedResults.Created($"/orders/{order.Id}", order);
    }
}
