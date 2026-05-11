using FluentAssertions;
using Microsoft.Extensions.DependencyInjection;
using OrderApi.Services;
using OrderApi.Tests.Infrastructure;

namespace OrderApi.Tests;

public sealed class CacheTests(RedisFixture fixture) : IClassFixture<RedisFixture>
{
    [Fact]
    public async Task CanSetAndGetValue_FromCache()
    {
        await using var scopeContext = CreateCacheScope();
        var cacheService = scopeContext.ServiceProvider.GetRequiredService<ICacheService>();
        var key = $"orders:{Guid.NewGuid():N}";
        var expected = new CachedOrder("Contoso", "Laptop");

        await cacheService.SetAsync(key, expected, TimeSpan.FromMinutes(1));
        var actual = await cacheService.GetAsync<CachedOrder>(key);

        actual.Should().BeEquivalentTo(expected);
    }

    [Fact]
    public async Task CacheExpires_AfterTtl()
    {
        await using var scopeContext = CreateCacheScope();
        var cacheService = scopeContext.ServiceProvider.GetRequiredService<ICacheService>();
        var key = $"orders:{Guid.NewGuid():N}";

        await cacheService.SetAsync(key, new CachedOrder("Fabrikam", "Monitor"), TimeSpan.FromSeconds(1));
        await Task.Delay(TimeSpan.FromSeconds(2));
        var cachedValue = await cacheService.GetAsync<CachedOrder>(key);

        cachedValue.Should().BeNull();
    }

    [Fact]
    public async Task CanDeleteValue_FromCache()
    {
        await using var scopeContext = CreateCacheScope();
        var cacheService = scopeContext.ServiceProvider.GetRequiredService<ICacheService>();
        var key = $"orders:{Guid.NewGuid():N}";

        await cacheService.SetAsync(key, new CachedOrder("Northwind", "Dock"), TimeSpan.FromMinutes(1));
        await cacheService.DeleteAsync(key);
        var cachedValue = await cacheService.GetAsync<CachedOrder>(key);

        cachedValue.Should().BeNull();
    }

    private AsyncServiceScope CreateCacheScope()
    {
        var services = new ServiceCollection();
        services.AddStackExchangeRedisCache(options => options.Configuration = fixture.ConnectionString);
        services.AddScoped<ICacheService, CacheService>();

        var provider = services.BuildServiceProvider();
        return provider.CreateAsyncScope();
    }

    private sealed record CachedOrder(string CustomerName, string Product);
}
