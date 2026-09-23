using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Options;

namespace ps12exeOnline;

/// <summary>
/// 基于内存缓存的按 IP 固定窗口限流器。相比 ASP.NET Core 内置的分区限流器，
/// 它用 <see cref="MemoryCache"/> 的过期与容量上限自动回收条目，不会因为大量不同 IP 而无限增长。
/// </summary>
public sealed class IpRateLimiter
{
	private sealed class Counter
	{
		public long Value;
	}

	private readonly IMemoryCache _cache;
	private readonly int _permitLimit;
	private readonly TimeSpan _window;

	public IpRateLimiter(IMemoryCache cache, IOptions<CompilerOptions> options)
	{
		_cache = cache;
		_permitLimit = Math.Max(1, options.Value.RequestsPerMinute);
		_window = TimeSpan.FromMinutes(1);
	}

	public bool TryAcquire(string partitionKey)
	{
		var counter = _cache.GetOrCreate(partitionKey, entry =>
		{
			entry.AbsoluteExpirationRelativeToNow = _window;
			entry.Size = 1;
			return new Counter();
		})!;
		return Interlocked.Increment(ref counter.Value) <= _permitLimit;
	}
}
