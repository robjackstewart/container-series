using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using OrderApi.Data;
using OrderApi.Endpoints;
using OrderApi.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddHealthChecks();

var postgresConnectionString = builder.Configuration.GetConnectionString("Postgres")
    ?? "Host=localhost;Port=5432;Database=orders;Username=postgres;Password=postgres";

var redisConnectionString = builder.Configuration.GetConnectionString("Redis")
    ?? "localhost:6379";

builder.Services.AddDbContext<AppDbContext>(options => options.UseNpgsql(postgresConnectionString));
builder.Services.AddStackExchangeRedisCache(options => options.Configuration = redisConnectionString);
builder.Services.AddScoped<IOrderService, OrderService>();
builder.Services.AddScoped<ICacheService, CacheService>();

builder.Services.ConfigureHttpJsonOptions(options =>
{
    options.SerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
});

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var dbContext = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    await dbContext.Database.MigrateAsync();
}

app.MapHealthChecks("/health");
app.MapOrderEndpoints();

app.Run();

public partial class Program;
