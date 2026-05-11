namespace OrderApi.Models;

public sealed class Order
{
    public Guid Id { get; set; }

    public string CustomerName { get; set; } = string.Empty;

    public string Product { get; set; } = string.Empty;

    public int Quantity { get; set; }

    public decimal TotalPrice { get; set; }

    public string Status { get; set; } = string.Empty;

    public DateTime CreatedAt { get; set; }
}
