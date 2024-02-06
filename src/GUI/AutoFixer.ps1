# 该脚本可以自动对齐相差较小的控件的位置和大小
function AutoFixer($Controls, $FixLimit = 4) {
	$SizesX = @()
	$SizesY = @()
	$LocationsX = @()
	$LocationsY = @()

	$SControls = @()
	$Controls | ForEach-Object {
		if ($_.GetType().Name -eq 'GroupBox') {
			$SubControls = $_.Controls
			AutoFixer $SubControls $FixLimit
		}
		else {
			$SControls += $_
		}
	}

	$SControls | ForEach-Object {
		$SizesX += $_.Size.Width; $SizesY += $_.Size.Height
		$LocationsX += $_.Location.X; $LocationsY += $_.Location.Y
	}

	function FixNumber($Number, $Array) {
		$min = $Array | Where-Object { $_ -ge $Number - $FixLimit } | Sort-Object | Select-Object -First 1
		$max = $Array | Where-Object { $_ -le $Number + $FixLimit } | Sort-Object | Select-Object -Last 1
		($min + $max ) / 2
	}

	$SControls | ForEach-Object {
		$_.Size = New-Object System.Drawing.Size (FixNumber $_.Size.Width $SizesX), (FixNumber $_.Size.Height $SizesY)
		$_.Location = New-Object System.Drawing.Point (FixNumber $_.Location.X $LocationsX), (FixNumber $_.Location.Y $LocationsY)
	}
}
