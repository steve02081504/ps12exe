# 编码与解码分别只依赖共用文件；两者合编后验证实际字节往返。
Add-Test @{
	Name  = 'ps12exe.lzma.source-boundaries'
	Group = 'ps12exe'
	Deps  = @('src/programFrames/LzmaCommon.cs', 'src/programFrames/LzmaEncode.cs', 'src/programFrames/LzmaDecode.cs')
	Run   = {
		param($ctx)
		$common = Join-Path $ctx.RepoRoot 'src/programFrames/LzmaCommon.cs'
		$encoder = Join-Path $ctx.RepoRoot 'src/programFrames/LzmaEncode.cs'
		$decoder = Join-Path $ctx.RepoRoot 'src/programFrames/LzmaDecode.cs'
		Add-Type -Path @($common, $encoder) -OutputAssembly (Join-Path $ctx.WorkDir 'encoder.dll')
		Add-Type -Path @($common, $decoder) -OutputAssembly (Join-Path $ctx.WorkDir 'decoder.dll')
		Add-Type -Path @($common, $encoder, $decoder)
		foreach ($data in @([byte[]]@(), [byte[]]@(0, 255, 1), [Text.Encoding]::UTF8.GetBytes(('LZMA 中文重复内容' * 10000)))) {
			$packed = [LzmaPackCodec]::Compress($data)
			$inputStream = [IO.MemoryStream]::new($packed)
			$outputStream = [LzmaCodec]::DecompressStream($inputStream)
			try {
				$result = [IO.MemoryStream]::new()
				try {
					$outputStream.CopyTo($result)
					Assert-Equal ([Convert]::ToBase64String($data)) ([Convert]::ToBase64String($result.ToArray())) 'LZMA 字节往返'
				}
				finally { $result.Dispose() }
			}
			finally { $outputStream.Dispose(); $inputStream.Dispose() }
		}
	}
}
