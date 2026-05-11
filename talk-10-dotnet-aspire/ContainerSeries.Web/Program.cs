using ContainerSeries.ServiceDefaults;
using ContainerSeries.Web.Components;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();
builder.Services.AddRazorComponents();

builder.Services.AddHttpClient("api", static client =>
{
    client.BaseAddress = new Uri("http://api");
});

builder.Services.AddScoped(sp => sp.GetRequiredService<IHttpClientFactory>().CreateClient("api"));

var app = builder.Build();

app.UseAntiforgery();
app.MapRazorComponents<App>();
app.MapDefaultEndpoints();

app.Run();
