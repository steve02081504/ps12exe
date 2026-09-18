# 框架自检：最小的端到端构建+运行，验证构建去重、缓存与并行通路。
Add-Test @{
	Name  = 'smoke.inline-hello'
	Group = 'misc'
	Deps  = @()
	Build = @{ Name = 'hello'; InputText = "'smoke-hello'"; Output = 'smoke-hello.exe' }
	Run   = {
		param($ctx)
		$exe = $ctx.Builds['hello']
		Assert-FileExists $exe 'hello exe 未产出'
		$r = Invoke-ExeCaptureMergedOutput -ExePath $exe
		Assert-Equal 0 $r.ExitCode 'hello 退出码'
		Assert-Match $r.Output 'smoke-hello' 'hello 输出'
	}
}
