using System.Text.Json.Serialization;

var builder = WebApplication.CreateBuilder(args);

// This is the traditional container equivalent - runs in a full OS process.
// Startup is typically slower than a Wasm module because the runtime, process,
// and container image layers all need to initialize.
builder.WebHost.UseUrls("http://0.0.0.0:8080");

var app = builder.Build();

var items = new List<Item>
{
    new(1, "Wasm module"),
    new(2, "Spin HTTP trigger"),
    new(3, "WASI sandbox")
};

app.MapGet("/", () => Results.Text(
    "Welcome to the traditional container demo! Runtime: .NET 8 minimal API in a full OS process.",
    "text/plain"));

app.MapGet("/health", () => Results.Json(new
{
    status = "healthy",
    runtime = "traditional"
}));

app.MapGet("/items", () => Results.Json(items));

app.MapPost("/items", (CreateItemRequest request) =>
{
    var newItem = new Item(items.Count + 1, request.Name);
    items.Add(newItem);

    return Results.Created($"/items/{newItem.Id}", new
    {
        message = "Item persisted in process memory for the lifetime of this container.",
        items
    });
});

app.Run();

internal record Item(int Id, string Name);
internal record CreateItemRequest([property: JsonPropertyName("name")] string Name);
