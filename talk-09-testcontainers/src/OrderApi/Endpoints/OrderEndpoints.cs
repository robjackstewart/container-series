using OrderApi.Models;
using OrderApi.Services;

namespace OrderApi.Endpoints;

public static class OrderEndpoints
{
    public static IEndpointRouteBuilder MapOrderEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/orders");

        group.MapGet(string.Empty, async (IOrderService orderService, CancellationToken cancellationToken) =>
        {
            var orders = await orderService.GetOrdersAsync(cancellationToken);
            return Results.Ok(orders);
        });

        group.MapGet("/{id:guid}", async (Guid id, IOrderService orderService, ICacheService cacheService, CancellationToken cancellationToken) =>
        {
            var cacheKey = GetCacheKey(id);
            var cachedOrder = await cacheService.GetAsync<Order>(cacheKey, cancellationToken);
            if (cachedOrder is not null)
            {
                return Results.Ok(cachedOrder);
            }

            var order = await orderService.GetOrderAsync(id, cancellationToken);
            if (order is null)
            {
                return Results.NotFound();
            }

            await cacheService.SetAsync(cacheKey, order, TimeSpan.FromMinutes(5), cancellationToken);
            return Results.Ok(order);
        });

        group.MapPost(string.Empty, async (CreateOrderRequest request, IOrderService orderService, ICacheService cacheService, CancellationToken cancellationToken) =>
        {
            var errors = Validate(request);
            if (errors.Count > 0)
            {
                return Results.ValidationProblem(errors);
            }

            var order = new Order
            {
                CustomerName = request.CustomerName.Trim(),
                Product = request.Product.Trim(),
                Quantity = request.Quantity,
                TotalPrice = request.TotalPrice,
                Status = request.Status.Trim(),
                CreatedAt = DateTime.UtcNow
            };

            var createdOrder = await orderService.CreateOrderAsync(order, cancellationToken);
            await cacheService.SetAsync(GetCacheKey(createdOrder.Id), createdOrder, TimeSpan.FromMinutes(5), cancellationToken);

            return Results.Created($"/orders/{createdOrder.Id}", createdOrder);
        });

        group.MapDelete("/{id:guid}", async (Guid id, IOrderService orderService, ICacheService cacheService, CancellationToken cancellationToken) =>
        {
            var deleted = await orderService.DeleteOrderAsync(id, cancellationToken);
            if (!deleted)
            {
                return Results.NotFound();
            }

            await cacheService.DeleteAsync(GetCacheKey(id), cancellationToken);
            return Results.NoContent();
        });

        return app;
    }

    private static string GetCacheKey(Guid id) => $"orders:{id}";

    private static Dictionary<string, string[]> Validate(CreateOrderRequest request)
    {
        var errors = new Dictionary<string, string[]>();

        if (string.IsNullOrWhiteSpace(request.CustomerName))
        {
            errors[nameof(request.CustomerName)] = ["Customer name is required."];
        }

        if (string.IsNullOrWhiteSpace(request.Product))
        {
            errors[nameof(request.Product)] = ["Product is required."];
        }

        if (request.Quantity <= 0)
        {
            errors[nameof(request.Quantity)] = ["Quantity must be greater than zero."];
        }

        if (request.TotalPrice <= 0)
        {
            errors[nameof(request.TotalPrice)] = ["Total price must be greater than zero."];
        }

        if (string.IsNullOrWhiteSpace(request.Status))
        {
            errors[nameof(request.Status)] = ["Status is required."];
        }

        return errors;
    }

    public sealed class CreateOrderRequest
    {
        public string CustomerName { get; init; } = string.Empty;
        public string Product { get; init; } = string.Empty;
        public int Quantity { get; init; }
        public decimal TotalPrice { get; init; }
        public string Status { get; init; } = string.Empty;
    }
}
