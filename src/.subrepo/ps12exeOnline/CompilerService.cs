using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Options;

namespace ps12exeOnline;

/// <summary>一次编译的结果：成功时 <see cref="Path"/> 指向缓存里的 exe，否则用 <see cref="ErrorCode"/> 标识失败。</summary>
public sealed record CompileResult(string? Path, string? ErrorCode, string? ErrorMessage)
{
	public bool Ok => Path is not null;

	public static CompileResult Success(string path) => new(path, null, null);
	public static CompileResult Failure(string code, string? message = null) => new(null, code, message);
}

/// <summary>
/// 把用户脚本写进临时文件，交给 <c>scripts/compile.ps1</c> 调用 ps12exe 编译，并对结果做内容哈希缓存。
/// 编译在独立的 PowerShell 子进程里执行，超时会杀掉整个进程树，避免拖垮 Web 进程。
/// </summary>
public sealed class CompilerService : IDisposable
{
	private readonly CompilerOptions _options;
	private readonly ILogger<CompilerService> _logger;
	private readonly SemaphoreSlim _slots;
	private readonly string _cacheDirectory;
	private readonly string _tempDirectory;
	private readonly string _workerScript;
	private readonly Lazy<string?> _modulePath;
	private readonly Lazy<string> _powerShellPath;

	public CompilerService(IOptions<CompilerOptions> options, IWebHostEnvironment environment, ILogger<CompilerService> logger)
	{
		_options = options.Value;
		_logger = logger;
		_slots = new SemaphoreSlim(Math.Max(1, _options.MaxConcurrency));

		_workerScript = Path.Combine(environment.ContentRootPath, "scripts", "compile.ps1");
		_cacheDirectory = ResolveCacheDirectory();
		_tempDirectory = Path.Combine(_cacheDirectory, "tmp");
		Directory.CreateDirectory(_tempDirectory);

		_modulePath = new(() => ResolveModulePath(environment));
		_powerShellPath = new(() => ResolvePowerShell());
	}

	public string CacheDirectory => _cacheDirectory;

	public async Task<CompileResult> CompileAsync(string content, string? locale, bool trusted, CancellationToken cancellationToken)
	{
		var sandbox = !trusted;
		var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(content))).ToLowerInvariant();
		var cachePath = Path.Combine(_cacheDirectory, $"{hash}{(sandbox ? "-sandbox" : string.Empty)}.exe");

		if (File.Exists(cachePath))
			return CompileResult.Success(cachePath);

		if (!await _slots.WaitAsync(TimeSpan.FromSeconds(_options.QueueTimeoutSeconds), cancellationToken).ConfigureAwait(false))
			return CompileResult.Failure("ServerBusy");

		var inputFile = Path.Combine(_tempDirectory, $"{hash}.ps1");
		var outputFile = Path.Combine(_tempDirectory, $"{hash}-{Guid.NewGuid():N}.exe");
		try
		{
			if (File.Exists(cachePath))
				return CompileResult.Success(cachePath);

			await File.WriteAllTextAsync(inputFile, content, new UTF8Encoding(false), cancellationToken).ConfigureAwait(false);

			var run = await RunCompilerAsync(inputFile, outputFile, locale, sandbox, cancellationToken).ConfigureAwait(false);
			if (!run.Ok)
				return run;

			try
			{
				File.Move(outputFile, cachePath, overwrite: false);
			}
			catch (IOException)
			{
				// 另一个并发请求抢先写好了同一份产物，直接用它的即可。
			}

			return CompileResult.Success(cachePath);
		}
		catch (OperationCanceledException)
		{
			return CompileResult.Failure("Canceled");
		}
		finally
		{
			TryDelete(inputFile);
			TryDelete(outputFile);
			_slots.Release();
		}
	}

	private async Task<CompileResult> RunCompilerAsync(string inputFile, string outputFile, string? locale, bool sandbox, CancellationToken cancellationToken)
	{
		if (!File.Exists(_workerScript))
			return CompileResult.Failure("CompileFailed", "compile.ps1 is missing from the deployment.");
		var modulePath = _modulePath.Value;
		if (modulePath is null)
			_logger.LogWarning("ps12exe module was not found on disk; the worker will try to import it by name.");

		var startInfo = new ProcessStartInfo(_powerShellPath.Value)
		{
			UseShellExecute = false,
			RedirectStandardOutput = true,
			RedirectStandardError = true,
			CreateNoWindow = true,
			WorkingDirectory = _cacheDirectory,
			ArgumentList =
			{
				"-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", _workerScript,
				"-InputFile", inputFile, "-OutputFile", outputFile,
			},
		};
		if (modulePath is not null)
		{
			startInfo.ArgumentList.Add("-ModulePath");
			startInfo.ArgumentList.Add(modulePath);
		}
		if (!string.IsNullOrEmpty(locale))
		{
			startInfo.ArgumentList.Add("-Locale");
			startInfo.ArgumentList.Add(locale);
		}
		if (sandbox)
			startInfo.ArgumentList.Add("-Sandbox");

		using var process = new Process { StartInfo = startInfo };
		try
		{
			process.Start();
		}
		catch (Exception ex)
		{
			return CompileResult.Failure("CompileFailed", $"Failed to start PowerShell: {ex.Message}");
		}

		var stdoutTask = process.StandardOutput.ReadToEndAsync();
		var stderrTask = process.StandardError.ReadToEndAsync();

		using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
		timeout.CancelAfter(TimeSpan.FromSeconds(Math.Max(1, _options.CompileTimeoutSeconds)));
		try
		{
			await process.WaitForExitAsync(timeout.Token).ConfigureAwait(false);
		}
		catch (OperationCanceledException)
		{
			TryKill(process);
			if (cancellationToken.IsCancellationRequested)
				return CompileResult.Failure("Canceled");
			_logger.LogWarning("Compilation timed out after {Seconds}s.", _options.CompileTimeoutSeconds);
			return CompileResult.Failure("Timeout", $"Compilation exceeded {_options.CompileTimeoutSeconds} seconds.");
		}

		var stdout = await stdoutTask.ConfigureAwait(false);
		var stderr = await stderrTask.ConfigureAwait(false);

		if (process.ExitCode != 0)
		{
			var message = string.IsNullOrWhiteSpace(stderr) ? stdout : stderr;
			_logger.LogInformation("Compilation failed (exit {ExitCode}): {Message}", process.ExitCode, message.Trim());
			return CompileResult.Failure("CompileFailed", message.Trim());
		}
		if (!File.Exists(outputFile))
			return CompileResult.Failure("CompileFailed", "The compiler produced no output.");

		return CompileResult.Success(outputFile);
	}

	private string ResolveCacheDirectory()
	{
		if (!string.IsNullOrWhiteSpace(_options.CacheDirectory))
			return Path.GetFullPath(_options.CacheDirectory!);

		var home = Environment.GetEnvironmentVariable("HOME");
		var site = Environment.GetEnvironmentVariable("WEBSITE_SITE_NAME");
		if (!string.IsNullOrEmpty(site) && !string.IsNullOrEmpty(home) && Directory.Exists(home))
			return Path.Combine(home, "data", "ps12exe-online-cache");

		return Path.Combine(Path.GetTempPath(), "ps12exe-online-cache");
	}

	private string? ResolveModulePath(IWebHostEnvironment environment)
	{
		if (!string.IsNullOrWhiteSpace(_options.ModulePath))
		{
			var configured = Path.GetFullPath(_options.ModulePath!, environment.ContentRootPath);
			return File.Exists(configured) ? configured : null;
		}

		var bundled = Path.Combine(environment.ContentRootPath, "compiler", "ps12exe.psm1");
		if (File.Exists(bundled))
			return bundled;

		for (var directory = new DirectoryInfo(environment.ContentRootPath); directory is not null; directory = directory.Parent)
		{
			var candidate = Path.Combine(directory.FullName, "ps12exe.psm1");
			if (File.Exists(candidate))
				return candidate;
		}

		return null;
	}

	private string ResolvePowerShell()
	{
		if (!string.IsNullOrWhiteSpace(_options.PowerShellPath))
			return _options.PowerShellPath!;

		if (OperatingSystem.IsWindows())
		{
			var windowsPowerShell = FindOnPath("powershell.exe");
			if (windowsPowerShell is not null)
				return windowsPowerShell;
		}

		return FindOnPath("pwsh") ?? (OperatingSystem.IsWindows() ? "powershell.exe" : "pwsh");
	}

	private static string? FindOnPath(string executable)
	{
		var path = Environment.GetEnvironmentVariable("PATH");
		if (string.IsNullOrEmpty(path))
			return null;

		var extensions = OperatingSystem.IsWindows()
			? (Environment.GetEnvironmentVariable("PATHEXT") ?? ".EXE;.CMD;.BAT").Split(';', StringSplitOptions.RemoveEmptyEntries)
			: [string.Empty];

		foreach (var directory in path.Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries))
		{
			foreach (var extension in extensions)
			{
				var candidate = Path.Combine(directory.Trim(), executable + extension.ToLowerInvariant());
				if (File.Exists(candidate))
					return candidate;
			}
		}
		return null;
	}

	private static void TryKill(Process process)
	{
		try
		{
			if (!process.HasExited)
				process.Kill(entireProcessTree: true);
		}
		catch
		{
			// 进程可能已自行退出，忽略。
		}
	}

	private static void TryDelete(string path)
	{
		try
		{
			if (File.Exists(path))
				File.Delete(path);
		}
		catch
		{
			// 文件可能正被占用，留给后续清理。
		}
	}

	public void Dispose() => _slots.Dispose();
}
