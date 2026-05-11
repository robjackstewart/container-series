using System.Text.Json;
using Microsoft.Extensions.Caching.Distributed;

namespace OrderApi.Services;

public interface ICacheService
{
    Task<T?> GetAsync<T>(string key, CancellationToken cancellationToken = default);
    Task SetAsync<T>(string key, T value, TimeSpan? ttl = null, CancellationToken cancellationToken = default);
    Task DeleteAsync(string key, CancellationToken cancellationToken = default);
}

public sealed class CacheService(IDistributedCache cache) : ICacheService
{
    private static readonly JsonSerializerOptions SerializerOptions = new(JsonSerializerDefaults.Web);

    public async Task<T?> GetAsync<T>(string key, CancellationToken cancellationToken = default)
    {
        var payload = await cache.GetStringAsync(key, cancellationToken);
        return payload is null ? default : JsonSerializer.Deserialize<T>(payload, SerializerOptions);
    }

    public async Task SetAsync<T>(string key, T value, TimeSpan? ttl = null, CancellationToken cancellationToken = default)
    {
        var payload = JsonSerializer.Serialize(value, SerializerOptions);
        var options = new DistributedCacheEntryOptions
        {
            AbsoluteExpirationRelativeToNow = ttl ?? TimeSpan.FromMinutes(5)
        };

        await cache.SetStringAsync(key, payload, options, cancellationToken);
    }

    public Task DeleteAsync(string key, CancellationToken cancellationToken = default)
    {
        return cache.RemoveAsync(key, cancellationToken);
    }
}
