using System;
using System.Web.UI;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using System.Threading;
using System.Linq;
using ps12exeOnline;

public partial class ps12exeOnlineMain : Page
{
	private const int MaxCompileThreads = 8;
	private const int MaxCompileTime = 20; // 秒
	private const int ReqLimitPerMin = 5;
	private const long MaxScriptFileSize = 2 * 1024 * 1024; // 2MB
	private const long MaxCachedFileSize = 32 * 1024 * 1024; // 32MB
	private static string CacheDir = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "outputs");

	private static readonly Dictionary<string, int> IpRequestCount = new Dictionary<string, int>();
	private static readonly Dictionary<string, DateTime> IpLastRequestTime = new Dictionary<string, DateTime>();

	private static DateTime LastCacheCleanTime = DateTime.Now;

	private static readonly SemaphoreSlim CompileThreads = new SemaphoreSlim(MaxCompileThreads);

	protected global::System.Web.UI.WebControls.Button compileButton;
	protected global::System.Web.UI.HtmlControls.HtmlTextArea inputText;

	protected void Page_Load(object sender, EventArgs e) {
		if (!IsPostBack) {
			if (compileButton != null) compileButton.Text = locale.CompileButtonText;
		}
	}

	protected void compileCode(object sender, EventArgs e) {
		Page.RegisterAsyncTask(new PageAsyncTask(async () => {
			try {
				string clientIP = Request.UserHostAddress;
				string codeInput = inputText.Value;

				if (System.Text.Encoding.UTF8.GetByteCount(codeInput) > MaxScriptFileSize && clientIP != "127.0.0.1")
					throw new Exception(locale.FileTooLarge);

				if (!CheckIpLimit(clientIP))
					throw new Exception(locale.TooManyRequests);

				string inputHash;
				using (var sha256 = System.Security.Cryptography.SHA256.Create())
				{
					var hashBytes = sha256.ComputeHash(System.Text.Encoding.UTF8.GetBytes(codeInput));
					inputHash = BitConverter.ToString(hashBytes).Replace("-", "").ToLower();
				}

				string cachedFile = Path.Combine(CacheDir, $"{inputHash}.exe");

				if (File.Exists(cachedFile)) {
					SendFile(cachedFile);
					return;
				}

				Directory.CreateDirectory(CacheDir);

				bool acquired = await CompileThreads.WaitAsync(TimeSpan.FromSeconds(MaxCompileTime));
				if (!acquired) throw new Exception(locale.ServerBusy);

				try {
					// use powershell api to compile by ps12exe
					var pwsh = System.Management.Automation.PowerShell.Create();

					// 准备编译参数
					var scriptBlock = @"
						param($InputScript, $OutputFile)
						try {
							Import-Module ../../../../ps12exe.psm1 -ErrorAction Stop
							$InputScript | ps12exe -outputFile $OutputFile -GuestMode:$true -ErrorAction Stop
						}
						catch { $LastExitCode = 1 }
						if ($LastExitCode) {
							throw $Error[0]
						}
					";

					// 使用参数化方式传递输入内容
					pwsh.AddScript(scriptBlock)
						.AddParameter("InputScript", codeInput)
						.AddParameter("OutputFile", cachedFile);

					// 执行编译
					try {
						var results = pwsh.Invoke();
					}
					catch (Exception pex) {
						throw new Exception(pex.Message);
					}

					// 确保文件已生成
					if (!File.Exists(cachedFile))
						throw new Exception(locale.CompileFailed);

					await CleanCacheIfNeeded();

					SendFile(cachedFile);
				}
				finally {
					CompileThreads.Release();
				}
			}
			catch (Exception ex) {
				string errorMessage = ex.Message.Replace("'", "\\'");
				ScriptManager.RegisterStartupScript(this, GetType(), "ErrorAlert",
					$"alert('{locale.CompileError}: {errorMessage}');", true);
			}
		}));
	}

	private bool CheckIpLimit(string clientIP) {
		if (clientIP == "127.0.0.1") return true;

		lock (IpRequestCount) {
			DateTime now = DateTime.Now;

			if (IpLastRequestTime.ContainsKey(clientIP) && (now - IpLastRequestTime[clientIP]).TotalMinutes >= 1) {
				IpRequestCount.Remove(clientIP);
				IpLastRequestTime.Remove(clientIP);
			}

			if (!IpRequestCount.ContainsKey(clientIP)) {
				IpRequestCount[clientIP] = 0;
				IpLastRequestTime[clientIP] = now;
			}

			IpRequestCount[clientIP]++;
			return IpRequestCount[clientIP] <= ReqLimitPerMin;
		}
	}

	private async Task CleanCacheIfNeeded() {
		if ((DateTime.Now - LastCacheCleanTime).TotalMinutes < 1) return;

		LastCacheCleanTime = DateTime.Now;

		var cacheFiles = Directory.GetFiles(CacheDir);
		long totalSize = cacheFiles.Sum(f => new FileInfo(f).Length);

		if (totalSize > MaxCachedFileSize) {
			var filesToDelete = cacheFiles
				.Select(f => new FileInfo(f))
				.OrderByDescending(f => f.LastAccessTime)
				.Take(cacheFiles.Length / 2);

			foreach (var file in filesToDelete) {
				try {
					await Task.Run(() => file.Delete());
				}
				catch { /* 忽略删除失败 */ }
			}
		}
	}

	private void SendFile(string filePath) {
		Response.ContentType = "application/octet-stream";
		Response.AddHeader("Content-Disposition", "attachment; filename=a.exe");
		Response.TransmitFile(filePath);
		Response.Flush();
		Response.End();
	}
}
