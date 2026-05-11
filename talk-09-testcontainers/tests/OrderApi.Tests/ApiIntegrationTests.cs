using System.Net;
using System.Net.Http.Json;
using FluentAssertions;
using OrderApi.Models;
using OrderApi.Tests.Infrastructure;

namespace OrderApi.Tests;

public sealed class ApiIntegrationTests(CustomWebApplicationFactory factory) : IClassFixture<CustomWebApplicationFactory>
{
    private readonly HttpClient _client = factory.CreateClient();

    [Fact]
    public async Task CreateOrder_Returns201_WithNewOrder()
    {
        var request = BuildRequest();

        var response = await _client.PostAsJsonAsync("/orders", request);
        var createdOrder = await response.Content.ReadFromJsonAsync<Order>();

        response.StatusCode.Should().Be(HttpStatusCode.Created);
        createdOrder.Should().NotBeNull();
        createdOrder!.Id.Should().NotBeEmpty();
        createdOrder.CustomerName.Should().Be(request.CustomerName);
    }

    [Fact]
    public async Task GetOrder_Returns200_WithOrder()
    {
        var createdOrder = await CreateOrderAsync();

        var response = await _client.GetAsync($"/orders/{createdOrder.Id}");
        var order = await response.Content.ReadFromJsonAsync<Order>();

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        order.Should().NotBeNull();
        order!.Id.Should().Be(createdOrder.Id);
    }

    [Fact]
    public async Task GetOrder_Returns404_WhenNotFound()
    {
        var response = await _client.GetAsync($"/orders/{Guid.NewGuid()}");

        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task CreateOrder_Returns400_WithInvalidData()
    {
        var request = new
        {
            customerName = string.Empty,
            product = string.Empty,
            quantity = 0,
            totalPrice = 0,
            status = string.Empty
        };

        var response = await _client.PostAsJsonAsync("/orders", request);

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task DeleteOrder_Returns204()
    {
        var createdOrder = await CreateOrderAsync();

        var deleteResponse = await _client.DeleteAsync($"/orders/{createdOrder.Id}");
        var getResponse = await _client.GetAsync($"/orders/{createdOrder.Id}");

        deleteResponse.StatusCode.Should().Be(HttpStatusCode.NoContent);
        getResponse.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task GetOrders_Returns200_WithList()
    {
        var createdOrder = await CreateOrderAsync();

        var response = await _client.GetAsync("/orders");
        var orders = await response.Content.ReadFromJsonAsync<List<Order>>();

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        orders.Should().NotBeNull();
        orders!.Should().Contain(x => x.Id == createdOrder.Id);
    }

    private async Task<Order> CreateOrderAsync()
    {
        var response = await _client.PostAsJsonAsync("/orders", BuildRequest());
        response.EnsureSuccessStatusCode();

        return (await response.Content.ReadFromJsonAsync<Order>())!;
    }

    private static CreateOrderRequest BuildRequest() => new(
        $"Customer-{Guid.NewGuid():N}",
        "USB-C Dock",
        2,
        189.50m,
        "Pending");

    private sealed record CreateOrderRequest(string CustomerName, string Product, int Quantity, decimal TotalPrice, string Status);
}
