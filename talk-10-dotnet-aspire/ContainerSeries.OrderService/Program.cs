using ContainerSeries.OrderService;
using ContainerSeries.ServiceDefaults;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();
builder.Services.AddProblemDetails();

var orderDbConnectionString = builder.Configuration.GetConnectionString("orderdb")
    ?? throw new InvalidOperationException("Connection string 'orderdb' was not configured.");
var rabbitMqConnectionString = builder.Configuration.GetConnectionString("rabbitmq")
    ?? throw new InvalidOperationException("Connection string 'rabbitmq' was not configured.");

builder.Services.AddDbContext<OrderDbContext>(options => options.UseNpgsql(orderDbConnectionString));
builder.Services.AddSingleton<IOrderPublisher, RabbitMqOrderPublisher>(_ => new RabbitMqOrderPublisher(rabbitMqConnectionString));

var app = builder.Build();

app.UseExceptionHandler();

await using (var scope = app.Services.CreateAsyncScope())
{
    var dbContext = scope.ServiceProvider.GetRequiredService<OrderDbContext>();
    await dbContext.Database.EnsureCreatedAsync();
}

app.MapGet("/", () => Results.Ok(new
{
    service = "orderservice",
    endpoints = new[] { "/orders", "/orders/{id}", "/health" }
}));

app.MapOrderEndpoints();
app.MapDefaultEndpoints();

app.Run();
