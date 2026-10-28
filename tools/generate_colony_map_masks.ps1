# Regenerate sector assets from the same polygons used for mouse hit testing.
param([switch]$OutlinesOnly)
Add-Type -AssemblyName System.Drawing
$repoRoot = Split-Path $PSScriptRoot -Parent
$geometry = [IO.File]::ReadAllText((Join-Path $repoRoot 'modules/game_library/colony_map_geometry.lua'))
$assetDirectory = Join-Path $repoRoot 'data/images/game/pvp_map'
$outline = New-Object System.Drawing.Bitmap(1013, 701)
$outlineGraphics = [Drawing.Graphics]::FromImage($outline)
$outlineGraphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
$pen = New-Object Drawing.Pen([Drawing.Color]::White, 2)
foreach ($sector in [regex]::Matches($geometry, '(?ms)^    (\w+) = \{(.*?)\n    \}')) {
    [Drawing.PointF[]]$points = @([regex]::Matches($sector.Groups[2].Value, '\{(\d+),\s*(\d+)\}') | ForEach-Object {
        New-Object Drawing.PointF([single]$_.Groups[1].Value, [single]$_.Groups[2].Value)
    })
    if (-not $OutlinesOnly) {
        $mask = New-Object Drawing.Bitmap(1013, 701)
        $graphics = [Drawing.Graphics]::FromImage($mask)
        $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.FillPolygon([Drawing.Brushes]::White, $points)
        $mask.Save((Join-Path $assetDirectory ($sector.Groups[1].Value + '.png')), [Drawing.Imaging.ImageFormat]::Png)
        $graphics.Dispose()
        $mask.Dispose()
    }
    $outlineGraphics.DrawPolygon($pen, $points)
}
$outline.Save((Join-Path $assetDirectory 'sector_outlines.png'), [Drawing.Imaging.ImageFormat]::Png)
$outlineGraphics.Dispose()
$outline.Dispose()
$pen.Dispose()
