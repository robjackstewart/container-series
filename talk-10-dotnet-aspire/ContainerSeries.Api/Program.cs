using System.Net.Http.Json;
using System.Text.Json;
using ContainerSeries.ServiceDefaults;
using Microsoft.Extensions.Caching.Distributed;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();
builder.AddRedisDistributedCache("redis");

builder.Services.AddHttpClient("orderservice", static client =>
{
    client.BaseAddress = new Uri("http://orderservice");
});

var app = builder.Build();

app.UseExceptionHandler();

app.MapGet("/", () => Results.Ok(new
{
    service = "api",
    endpoints = new[] { "/orders", "/cache-test", "/health" }
}));

app.MapGet("/orders", async (IHttpClientFactory httpClientFactory, CancellationToken cancellationToken) =>
{
    using var response = await httpClientFactory.CreateClient("orderservice").GetAsync("/orders", cancellationToken);
    return await ToResultAsync(response, cancellationToken);
});

app.MapPost("/orders", async (CreateOrderRequest request, IHttpClientFactory httpClientFactory, CancellationToken cancellationToken) =>
{
    using var response = await httpClientFactory.CreateClient("orderservice").PostAsJsonAsync("/orders", request, cancellationToken);
    return await ToResultAsync(response, cancellationToken);
});

app.MapGet("/cache-test", async (IDistributedCache cache, CancellationToken cancellationToken) =>
{
    const string cacheKey = "talk-10-cache-test";

    var cachedValue = await cache.GetStringAsync(cacheKey, cancellationToken);
    if (cachedValue is null)
    {
        var generated = JsonSerializer.Serialize(new
        {
            message = "Hello from Redis through .NET Aspire",
            generatedAtUtc = DateTimeOffset.UtcNow
        });

        await cache.SetStringAsync(
            cacheKey,
            generated,
            new DistributedCacheEntryOptions
            {
                AbsoluteExpirationRelativeToNow = TimeSpan.FromSeconds(30)
            },
            cancellationToken);

        return Results.Ok(new
        {
            source = "generated",
            payload = JsonSerializer.Deserialize<JsonElement>(generated)
        });
    }

    return Results.Ok(new
    {
        source = "cache",
        payload = JsonSerializer.Deserialize<JsonElement>(cachedValue)
    });
});

app.MapDefaultEndpoints();

app.Run();

static async Task<IResult> ToResultAsync(HttpResponseMessage response, CancellationToken cancellationToken)
{
    var content = await response.Content.ReadAsStringAsync(cancellationToken);
    var contentType = response.Content.Headers.ContentType?.ToString() ?? "application/json";

    return Results.Content(content, contentType, statusCode: (int)response.StatusCode);
}

public sealed record CreateOrderRequest(string CustomerName, string ProductName, int Quantity);
