using Microsoft.Extensions.Options;

namespace ps12exeOnline;

/// <summary>
/// 定时检查产物缓存目录，超过配置上限时按最旧的写入时间（跳过最近仍在使用的文件）删除一半，避免磁盘被撑满。
/// </summary>
public sealed class CacheCleanupService : BackgroundService
{
	private static readonly TimeSpan MinimumAge = TimeSpan.FromMinutes(5);

	private readonly CompilerService _compiler;
	private readonly CompilerOptions _options;
	private readonly ILogger<CacheCleanupService> _logger;

	public CacheCleanupService(CompilerService compiler, IOptions<CompilerOptions> options, ILogger<CacheCleanupService> logger)
	{
		_compiler = compiler;
		_options = options.Value;
		_logger = logger;
	}

	protected override async Task ExecuteAsync(CancellationToken stoppingToken)
	{
		var interval = TimeSpan.FromMinutes(Math.Max(1, _options.CacheCleanupMinutes));
		while (!stoppingToken.IsCancellationRequested)
		{
			try
			{
				await Task.Delay(interval, stoppingToken).ConfigureAwait(false);
			}
			catch (OperationCanceledException)
			{
				break;
			}
			Cleanup();
		}
	}

	private void Cleanup()
	{
		try
		{
			var directory = new DirectoryInfo(_compiler.CacheDirectory);
			if (!directory.Exists)
				return;

			var files = directory.GetFiles("*.exe", SearchOption.TopDirectoryOnly);
			var total = files.Sum(file => file.Length);
			if (total <= _options.MaxCacheBytes)
				return;

			var cutoff = DateTime.UtcNow - MinimumAge;
			var deleted = 0;
			foreach (var file in files.OrderBy(file => file.LastWriteTimeUtc))
			{
				if (total <= _options.MaxCacheBytes / 2)
					break;
				if (file.LastWriteTimeUtc > cutoff)
					continue;
				try
				{
					var length = file.Length;
					file.Delete();
					total -= length;
					deleted++;
				}
				catch (IOException)
				{
					// 文件正在被下载，留到下一轮再清理。
				}
			}

			if (deleted > 0)
				_logger.LogInformation("Cache cleanup removed {Count} files; {Remaining} bytes left.", deleted, total);
		}
		catch (Exception ex)
		{
			_logger.LogWarning(ex, "Cache cleanup failed.");
		}
	}
}
