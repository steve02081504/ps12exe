namespace ps12exeOnline;

/// <summary>
/// 绑定 appsettings.json 的 <c>Compiler</c> 节，控制编译服务的并发、超时、缓存与限流。
/// 所有项都可以用环境变量覆盖（例如 <c>Compiler__MaxConcurrency</c>），方便在 Azure App Service 里调整。
/// </summary>
public sealed class CompilerOptions
{
	public const string SectionName = "Compiler";

	/// <summary>同时进行的编译任务上限。</summary>
	public int MaxConcurrency { get; set; } = 4;

	/// <summary>单次编译的最长执行时间（秒），超时后杀掉整个进程树。</summary>
	public int CompileTimeoutSeconds { get; set; } = 90;

	/// <summary>等待空闲编译槽位的最长时间（秒），超时返回「服务器繁忙」。</summary>
	public int QueueTimeoutSeconds { get; set; } = 30;

	/// <summary>单个请求允许的脚本最大字节数（UTF-8）。</summary>
	public long MaxScriptBytes { get; set; } = 2 * 1024 * 1024;

	/// <summary>每个 IP 每分钟允许的编译请求数。</summary>
	public int RequestsPerMinute { get; set; } = 5;

	/// <summary>缓存目录总大小上限（字节），超出后按最旧写入时间清理。</summary>
	public long MaxCacheBytes { get; set; } = 256L * 1024 * 1024;

	/// <summary>后台缓存清理的间隔（分钟）。</summary>
	public int CacheCleanupMinutes { get; set; } = 10;

	/// <summary>ps12exe 模块（ps12exe.psm1）路径；留空则自动探测仓库根或发布目录下的 compiler/。</summary>
	public string? ModulePath { get; set; }

	/// <summary>PowerShell 可执行文件路径；留空则自动探测 powershell.exe / pwsh。</summary>
	public string? PowerShellPath { get; set; }

	/// <summary>产物缓存目录；留空则使用 App Service 的 HOME 或系统临时目录。</summary>
	public string? CacheDirectory { get; set; }

	/// <summary>来自本机回环地址的请求是否跳过 Sandbox（便于本地调试）。</summary>
	public bool TrustLoopback { get; set; } = true;

	/// <summary>允许传给 ps12exe 的界面语言代码；不在列表中的语言会被忽略。</summary>
	public string[] AllowedLocales { get; set; } =
		["en-US", "en-UK", "zh-CN", "ja-JP", "fr-FR", "es-ES", "hi-IN"];
}
