namespace ps12exeOnline;

/// <summary>
/// 定位页面用到的静态素材：优先用网站目录里的文件，找不到时回退到仓库或发布包 <c>compiler/</c> 里的原始文件。
/// </summary>
public sealed class AssetLocator
{
	private readonly string _contentRoot;
	private readonly Lazy<string?> _favicon;
	private readonly Lazy<string?> _backgroundMusic;

	public AssetLocator(IWebHostEnvironment environment)
	{
		_contentRoot = environment.ContentRootPath;
		_favicon = new(() => Locate("favicon.ico", Path.Combine("img", "icon.ico"), Path.Combine("compiler", "img", "icon.ico")));
		_backgroundMusic = new(() => Locate("bgm.mid", Path.Combine("src", "bin", "Unravel.mid"), Path.Combine("compiler", "src", "bin", "Unravel.mid")));
	}

	public string? Favicon => _favicon.Value;
	public string? BackgroundMusic => _backgroundMusic.Value;

	private string? Locate(string webName, params string[] fallbackRelativePaths)
	{
		var repositoryRoot = FindRepositoryRoot();
		foreach (var relativePath in fallbackRelativePaths)
		{
			foreach (var root in new[] { _contentRoot, repositoryRoot })
			{
				if (root is null)
					continue;
				var candidate = Path.Combine(root, relativePath);
				if (File.Exists(candidate))
					return candidate;
			}
		}

		var webCandidate = Path.Combine(_contentRoot, "wwwroot", webName);
		return File.Exists(webCandidate) ? webCandidate : null;
	}

	private string? FindRepositoryRoot()
	{
		for (var directory = new DirectoryInfo(_contentRoot); directory is not null; directory = directory.Parent)
		{
			if (File.Exists(Path.Combine(directory.FullName, "ps12exe.psm1")))
				return directory.FullName;
		}
		return null;
	}
}
