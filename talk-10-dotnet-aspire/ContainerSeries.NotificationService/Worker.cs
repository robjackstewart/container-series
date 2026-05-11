using System.Diagnostics;
using System.Text;
using System.Text.Json;
using RabbitMQ.Client;

namespace ContainerSeries.NotificationService;

public sealed class Worker(ILogger<Worker> logger, IConfiguration configuration) : BackgroundService
{
    private const string QueueName = "orders.created";
    private static readonly ActivitySource ActivitySource = new("ContainerSeries.NotificationService");
    private readonly string _connectionString = configuration.GetConnectionString("rabbitmq")
        ?? throw new InvalidOperationException("Connection string 'rabbitmq' was not configured.");

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation("Notification worker started.");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await ProcessMessagesAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Notification worker lost its RabbitMQ connection. Retrying shortly.");
                await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
            }
        }
    }

    private async Task ProcessMessagesAsync(CancellationToken stoppingToken)
    {
        var connectionFactory = new ConnectionFactory
        {
            Uri = new Uri(_connectionString)
        };

        await using var connection = await connectionFactory.CreateConnectionAsync(cancellationToken: stoppingToken);
        await using var channel = await connection.CreateChannelAsync(cancellationToken: stoppingToken);

        await channel.QueueDeclareAsync(
            queue: QueueName,
            durable: false,
            exclusive: false,
            autoDelete: false,
            arguments: null,
            cancellationToken: stoppingToken);

        logger.LogInformation("Connected to RabbitMQ queue {QueueName}.", QueueName);

        while (!stoppingToken.IsCancellationRequested)
        {
            var delivery = await channel.BasicGetAsync(QueueName, autoAck: false, cancellationToken: stoppingToken);
            if (delivery is null)
            {
                await Task.Delay(TimeSpan.FromSeconds(1), stoppingToken);
                continue;
            }

            var payload = Encoding.UTF8.GetString(delivery.Body.ToArray());
            var order = JsonSerializer.Deserialize<OrderCreatedMessage>(payload);
            if (order is null)
            {
                logger.LogWarning("Received an invalid message from RabbitMQ: {Payload}", payload);
                await channel.BasicAckAsync(delivery.DeliveryTag, multiple: false, cancellationToken: stoppingToken);
                continue;
            }

            using var activity = ActivitySource.StartActivity("process order notification", ActivityKind.Consumer);
            activity?.SetTag("messaging.system", "rabbitmq");
            activity?.SetTag("messaging.destination.name", QueueName);
            activity?.SetTag("order.id", order.Id);

            logger.LogInformation(
                "Sending notification for order {OrderId}: {Quantity} x {ProductName} for {CustomerName}.",
                order.Id,
                order.Quantity,
                order.ProductName,
                order.CustomerName);

            await Task.Delay(TimeSpan.FromMilliseconds(200), stoppingToken);
            await channel.BasicAckAsync(delivery.DeliveryTag, multiple: false, cancellationToken: stoppingToken);
        }
    }

    private sealed record OrderCreatedMessage(int Id, string CustomerName, string ProductName, int Quantity, DateTimeOffset CreatedAtUtc);
}
