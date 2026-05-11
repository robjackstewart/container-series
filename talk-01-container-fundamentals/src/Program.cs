var builder = WebApplication.CreateBuilder(args);

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new()
    {
        Title = "Weather API",
        Version = "v1",
        Description = "A .NET 8 minimal API used to demonstrate container fundamentals."
    });
});

var app = builder.Build();

app.UseSwagger();
app.UseSwaggerUI();

var summaries = new[]
{
    "Freezing",
    "Bracing",
    "Chilly",
    "Cool",
    "Mild",
    "Warm",
    "Balmy",
    "Hot",
    "Sweltering",
    "Scorching"
};

app.MapGet("/health", () => Results.Ok(new { status = "healthy" }))
    .WithName("GetHealth")
    .WithTags("Diagnostics")
    .WithSummary("Returns the health status of the API.")
    .WithDescription("Simple liveness endpoint for demos and container health verification.");

app.MapGet("/info", (IHostEnvironment environment) =>
    Results.Ok(new
    {
        app = "Weather API",
        version = builder.Configuration["APP_VERSION"] ?? "dev",
        environment = environment.EnvironmentName
    }))
    .WithName("GetInfo")
    .WithTags("Diagnostics")
    .WithSummary("Returns application metadata.")
    .WithDescription("Shows the app name, version, and active ASP.NET Core environment.");

app.MapGet("/weatherforecast", () =>
    {
        var forecast = Enumerable.Range(1, 5)
            .Select(index => new WeatherForecast(
                DateOnly.FromDateTime(DateTime.UtcNow.AddDays(index)),
                Random.Shared.Next(-20, 55),
                summaries[Random.Shared.Next(summaries.Length)]))
            .ToArray();

        return Results.Ok(forecast);
    })
    .WithName("GetWeatherForecast")
    .WithTags("Weather")
    .WithSummary("Returns a five day sample weather forecast.")
    .WithDescription("Generates random weather data so the API has a realistic JSON response for container demos.");

app.Run();

internal sealed record WeatherForecast(DateOnly Date, int TemperatureC, string Summary)
{
    public int TemperatureF => 32 + (int)(TemperatureC / 0.5556);
}
