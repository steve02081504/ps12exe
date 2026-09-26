using System.Net;
using System.Text;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.Server.IIS;
using Microsoft.Extensions.Options;
using ps12exeOnline;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<CompilerOptions>(builder.Configuration.GetSection(CompilerOptions.SectionName));
builder.Services.AddSingleton<CompilerService>();
builder.Services.AddSingleton<AssetLocator>();
builder.Services.AddSingleton<IpRateLimiter>();
builder.Services.AddHostedService<CacheCleanupService>();

// 限流计数放进有容量上限的内存缓存，过期即回收，避免大量不同来源 IP 造成内存增长。
builder.Services.AddMemoryCache(options =>
{
	options.SizeLimit = 100_000;
	options.ExpirationScanFrequency = TimeSpan.FromMinutes(1);
});

// Azure App Service / 反向代理会通过 X-Forwarded-* 传递真实来源，清空默认白名单以信任平台注入的值。
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
	options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
	options.ForwardLimit = 1;
	options.KnownIPNetworks.Clear();
	options.KnownProxies.Clear();
});

// 请求体上限：脚本大小上限 + JSON/编码开销；让 Kestrel 与 IIS 在读取前就拒绝超大请求。
var maxRequestBodySize = (builder.Configuration.GetValue("Compiler:MaxScriptBytes", 2 * 1024 * 1024L) * 4) + (64 * 1024);
builder.WebHost.ConfigureKestrel(options => options.Limits.MaxRequestBodySize = maxRequestBodySize);
builder.Services.Configure<IISServerOptions>(options => options.MaxRequestBodySize = maxRequestBodySize);

var app = builder.Build();

app.UseForwardedHeaders();
app.UseDefaultFiles();
app.UseStaticFiles();

app.MapGet("/healthz", () => Results.Ok(new { status = "ok" }));

app.MapGet("/favicon.ico", (AssetLocator assets) =>
	assets.Favicon is string path ? Results.File(path, "image/x-icon") : Results.NotFound());

app.MapGet("/bgm.mid", (AssetLocator assets) =>
	assets.BackgroundMusic is string path ? Results.File(path, "audio/midi") : Results.NotFound());

app.MapPost("/api/compile", async (
	CompileRequest request,
	HttpContext http,
	CompilerService compiler,
	IpRateLimiter rateLimiter,
	IOptions<CompilerOptions> optionsAccessor,
	CancellationToken cancellationToken) =>
{
	var options = optionsAccessor.Value;
	var content = request.Content ?? string.Empty;

	if (string.IsNullOrWhiteSpace(content))
		return Error(StatusCodes.Status400BadRequest, "EmptyInput", "The script is empty.");

	// 回环地址视为本机调试，和自托管 WebServer 一样跳过大小/限流/Sandbox。
	var trusted = options.TrustLoopback && IsLoopback(http.Connection.RemoteIpAddress);

	if (!trusted)
	{
		if (Encoding.UTF8.GetByteCount(content) > options.MaxScriptBytes)
			return Error(StatusCodes.Status413PayloadTooLarge, "FileTooLarge", "The script is too large.");

		if (!rateLimiter.TryAcquire(http.Connection.RemoteIpAddress?.ToString() ?? "unknown"))
		{
			http.Response.Headers.RetryAfter = "60";
			return Error(StatusCodes.Status429TooManyRequests, "TooManyRequests", "Too many requests, please try again later.");
		}
	}

	var result = await compiler.CompileAsync(content, NormalizeLocale(request.Locale, options), trusted, cancellationToken);

	if (result.Ok)
		return Results.File(result.Path!, "application/octet-stream", "a.exe");

	return result.ErrorCode switch
	{
		"ServerBusy" => Error(StatusCodes.Status503ServiceUnavailable, result.ErrorCode, "The server is busy, please try again later."),
		"Timeout" => Error(StatusCodes.Status504GatewayTimeout, result.ErrorCode, result.ErrorMessage),
		"Canceled" => Error(StatusCodes.Status499ClientClosedRequest, result.ErrorCode, "The request was cancelled."),
		_ => Error(StatusCodes.Status500InternalServerError, result.ErrorCode ?? "CompileFailed", result.ErrorMessage),
	};
});

app.Run();

static IResult Error(int statusCode, string code, string? message) =>
	Results.Json(new { error = code, message = message ?? code }, statusCode: statusCode);

static bool IsLoopback(IPAddress? address) => address is not null && IPAddress.IsLoopback(address);

static string? NormalizeLocale(string? locale, CompilerOptions options)
{
	if (string.IsNullOrWhiteSpace(locale))
		return null;
	return options.AllowedLocales.FirstOrDefault(allowed => string.Equals(allowed, locale.Trim(), StringComparison.OrdinalIgnoreCase));
}

internal sealed record CompileRequest(string? Content, string? Locale);
