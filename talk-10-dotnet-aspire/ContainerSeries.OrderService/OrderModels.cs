using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using RabbitMQ.Client;

namespace ContainerSeries.OrderService;

public sealed class OrderDbContext(DbContextOptions<OrderDbContext> options) : DbContext(options)
{
    public DbSet<Order> Orders => Set<Order>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        var entity = modelBuilder.Entity<Order>();

        entity.ToTable("orders");
        entity.HasKey(order => order.Id);
        entity.Property(order => order.CustomerName).HasMaxLength(200).IsRequired();
        entity.Property(order => order.ProductName).HasMaxLength(200).IsRequired();
        entity.Property(order => order.Quantity).IsRequired();
        entity.Property(order => order.Status).HasMaxLength(50).IsRequired();
        entity.Property(order => order.CreatedAtUtc).IsRequired();
    }
}

public sealed class Order
{
    public int Id { get; set; }

    public string CustomerName { get; set; } = string.Empty;

    public string ProductName { get; set; } = string.Empty;

    public int Quantity { get; set; }

    public string Status { get; set; } = string.Empty;

    public DateTimeOffset CreatedAtUtc { get; set; }
}

public sealed record CreateOrderRequest(string CustomerName, string ProductName, int Quantity);

public sealed record OrderCreatedMessage(int Id, string CustomerName, string ProductName, int Quantity, DateTimeOffset CreatedAtUtc);

public interface IOrderPublisher
{
    Task PublishOrderCreatedAsync(Order order, CancellationToken cancellationToken);
}

public sealed class RabbitMqOrderPublisher(string connectionString) : IOrderPublisher
{
    private const string QueueName = "orders.created";

    public async Task PublishOrderCreatedAsync(Order order, CancellationToken cancellationToken)
    {
        var connectionFactory = new ConnectionFactory
        {
            Uri = new Uri(connectionString)
        };

        await using var connection = await connectionFactory.CreateConnectionAsync(cancellationToken: cancellationToken);
        await using var channel = await connection.CreateChannelAsync(cancellationToken: cancellationToken);

        await channel.QueueDeclareAsync(
            queue: QueueName,
            durable: false,
            exclusive: false,
            autoDelete: false,
            arguments: null,
            cancellationToken: cancellationToken);

        var message = new OrderCreatedMessage(order.Id, order.CustomerName, order.ProductName, order.Quantity, order.CreatedAtUtc);
        var body = JsonSerializer.SerializeToUtf8Bytes(message);
        var properties = new BasicProperties
        {
            ContentType = "application/json"
        };

        await channel.BasicPublishAsync(
            exchange: string.Empty,
            routingKey: QueueName,
            mandatory: false,
            basicProperties: properties,
            body: body,
            cancellationToken: cancellationToken);
    }
}
