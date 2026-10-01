# Compiler-tool regression: const values disappear from IL, but runtime C# still needs their fields.
Add-Test @{
	Name = 'packaging.constant-roots'
	Group = 'packaging'
	Deps = @('tools/AsmResolver/')
	Run = {
		param($ctx)
		$dotnet = (Get-Command dotnet -ErrorAction Stop).Source
		$packRoot = Join-Path (Split-Path $dotnet) 'packs/Microsoft.NETCore.App.Ref'
		$pack = Get-ChildItem $packRoot -Directory | Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } |
			Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
		$version = [version]$pack.Name
		$tfm = "net$($version.Major).$($version.Minor)"
		$refs = Join-Path $pack.FullName "ref/$tfm"
		$fixture = Join-Path $ctx.WorkDir 'fixture'
		New-Item -ItemType Directory -Path $fixture -Force | Out-Null
		[IO.File]::WriteAllText("$fixture/Fixture.csproj", @"
<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>$tfm</TargetFramework><AssemblyName>AsmResolver.TestConstants</AssemblyName></PropertyGroup></Project>
"@, [Text.UTF8Encoding]::new($false))
		[IO.File]::WriteAllText("$fixture/Constants.cs", @'
namespace Fixture {
    public class Outer {
        public enum Mode { Used = 1, Unused = 2 }
        public const string Label = "label";
        public const int Unused = 42;
    }
}
'@, [Text.UTF8Encoding]::new($true))
		& $dotnet build "$fixture/Fixture.csproj" -c Release -nologo | Out-Host
		Assert-Equal 0 $LASTEXITCODE 'Build constant fixture'
		$project = Join-Path $ctx.RepoRoot 'tools/AsmResolver/LinkerRoots/LinkerRoots.csproj'
		& $dotnet restore $project -p:TargetFramework=$tfm -nologo | Out-Host
		Assert-Equal 0 $LASTEXITCODE 'Restore constant analyzer'
		& $dotnet build $project --no-restore -c Release -p:TargetFramework=$tfm -nologo | Out-Host
		Assert-Equal 0 $LASTEXITCODE 'Build constant analyzer'
		$source = Join-Path $ctx.WorkDir 'Root.cs'
		[IO.File]::WriteAllText($source, @'
using Alias = Fixture.Outer.Mode;
using static Fixture.Outer;
class Root {
    static void Main() {
        System.Console.WriteLine(Alias.Used);
        System.Console.WriteLine(Label);
        // Unused and Alias.Unused must not become roots merely by appearing in a comment.
    }
}
'@, [Text.UTF8Encoding]::new($true))
		$analyzer = Join-Path (Split-Path $project) "bin/Release/$tfm/LinkerRoots.dll"
		$descriptor = Join-Path $ctx.WorkDir 'roots.xml'
		& $dotnet $analyzer "$fixture/bin/Release/$tfm" $refs $descriptor $source | Out-Host
		Assert-Equal 0 $LASTEXITCODE 'Analyze aliased and imported constants'
		[xml]$xml = Get-Content -LiteralPath $descriptor -Raw
		$types = @($xml.linker.assembly.type)
		Assert-Equal 'AsmResolver.TestConstants' $xml.linker.assembly.fullname 'Descriptor assembly'
		Assert-Equal 2 $types.Count 'Only referenced declaring types should survive'
		Assert-Equal 'Used' (@($types | Where-Object fullname -eq 'Fixture.Outer/Mode')[0].field.name) 'Nested enum through alias'
		Assert-Equal 'Label' (@($types | Where-Object fullname -eq 'Fixture.Outer')[0].field.name) 'Constant through using static'
	}
}
