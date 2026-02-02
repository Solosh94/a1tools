Add-Type -AssemblyName System.Drawing

$sourcePath = 'H:\A1Chimney\a1_tools\assets\icons\app_icon.png'
$sourceImage = [System.Drawing.Image]::FromFile($sourcePath)

Write-Host "Updating all platform icons from app_icon.png..." -ForegroundColor Cyan

# Function to resize and save PNG
function Save-ResizedPng {
    param($size, $destPath)
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $graphics = [System.Drawing.Graphics]::FromImage($bmp)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.DrawImage($sourceImage, 0, 0, $size, $size)
    $graphics.Dispose()
    $bmp.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "  Created: $destPath" -ForegroundColor Gray
}

# Function to create ICO with multiple sizes
function Save-Ico {
    param($destPath, $sizes)

    $ms = New-Object System.IO.MemoryStream
    $writer = New-Object System.IO.BinaryWriter($ms)

    # ICO Header
    $writer.Write([Int16]0)           # Reserved
    $writer.Write([Int16]1)           # Type (1 = ICO)
    $writer.Write([Int16]$sizes.Count) # Number of images

    $offset = 6 + (16 * $sizes.Count)
    $imageData = @()

    foreach ($size in $sizes) {
        $bmp = New-Object System.Drawing.Bitmap($size, $size)
        $graphics = [System.Drawing.Graphics]::FromImage($bmp)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.DrawImage($sourceImage, 0, 0, $size, $size)
        $graphics.Dispose()

        $pngStream = New-Object System.IO.MemoryStream
        $bmp.Save($pngStream, [System.Drawing.Imaging.ImageFormat]::Png)
        $pngBytes = $pngStream.ToArray()
        $pngStream.Dispose()
        $bmp.Dispose()

        $imageData += ,@($size, $pngBytes)
    }

    # Write directory entries
    foreach ($data in $imageData) {
        $size = $data[0]
        $bytes = $data[1]
        $writer.Write([byte]$(if ($size -eq 256) { 0 } else { $size }))
        $writer.Write([byte]$(if ($size -eq 256) { 0 } else { $size }))
        $writer.Write([byte]0)
        $writer.Write([byte]0)
        $writer.Write([Int16]1)
        $writer.Write([Int16]32)
        $writer.Write([Int32]$bytes.Length)
        $writer.Write([Int32]$offset)
        $offset += $bytes.Length
    }

    foreach ($data in $imageData) {
        $writer.Write($data[1])
    }

    $writer.Flush()
    [System.IO.File]::WriteAllBytes($destPath, $ms.ToArray())
    $writer.Dispose()
    $ms.Dispose()
    Write-Host "  Created: $destPath" -ForegroundColor Gray
}

# ============================================================
# WINDOWS - app_icon.ico
# ============================================================
Write-Host ""
Write-Host "==> Windows Icons" -ForegroundColor Yellow
Save-Ico 'H:\A1Chimney\a1_tools\windows\runner\resources\app_icon.ico' @(16, 32, 48, 64, 128, 256)

# ============================================================
# ANDROID - mipmap icons
# ============================================================
Write-Host ""
Write-Host "==> Android Icons" -ForegroundColor Yellow
$androidBase = 'H:\A1Chimney\a1_tools\android\app\src\main\res'

# Android icon sizes: mdpi=48, hdpi=72, xhdpi=96, xxhdpi=144, xxxhdpi=192
Save-ResizedPng 48 "$androidBase\mipmap-mdpi\ic_launcher.png"
Save-ResizedPng 72 "$androidBase\mipmap-hdpi\ic_launcher.png"
Save-ResizedPng 96 "$androidBase\mipmap-xhdpi\ic_launcher.png"
Save-ResizedPng 144 "$androidBase\mipmap-xxhdpi\ic_launcher.png"
Save-ResizedPng 192 "$androidBase\mipmap-xxxhdpi\ic_launcher.png"

# ============================================================
# iOS - AppIcon.appiconset
# ============================================================
Write-Host ""
Write-Host "==> iOS Icons" -ForegroundColor Yellow
$iosBase = 'H:\A1Chimney\a1_tools\ios\Runner\Assets.xcassets\AppIcon.appiconset'

# iOS required sizes
Save-ResizedPng 1024 "$iosBase\Icon-App-1024x1024@1x.png"
Save-ResizedPng 20 "$iosBase\Icon-App-20x20@1x.png"
Save-ResizedPng 40 "$iosBase\Icon-App-20x20@2x.png"
Save-ResizedPng 60 "$iosBase\Icon-App-20x20@3x.png"
Save-ResizedPng 29 "$iosBase\Icon-App-29x29@1x.png"
Save-ResizedPng 58 "$iosBase\Icon-App-29x29@2x.png"
Save-ResizedPng 87 "$iosBase\Icon-App-29x29@3x.png"
Save-ResizedPng 40 "$iosBase\Icon-App-40x40@1x.png"
Save-ResizedPng 80 "$iosBase\Icon-App-40x40@2x.png"
Save-ResizedPng 120 "$iosBase\Icon-App-40x40@3x.png"
Save-ResizedPng 50 "$iosBase\Icon-App-50x50@1x.png"
Save-ResizedPng 100 "$iosBase\Icon-App-50x50@2x.png"
Save-ResizedPng 57 "$iosBase\Icon-App-57x57@1x.png"
Save-ResizedPng 114 "$iosBase\Icon-App-57x57@2x.png"
Save-ResizedPng 120 "$iosBase\Icon-App-60x60@2x.png"
Save-ResizedPng 180 "$iosBase\Icon-App-60x60@3x.png"
Save-ResizedPng 72 "$iosBase\Icon-App-72x72@1x.png"
Save-ResizedPng 144 "$iosBase\Icon-App-72x72@2x.png"
Save-ResizedPng 76 "$iosBase\Icon-App-76x76@1x.png"
Save-ResizedPng 152 "$iosBase\Icon-App-76x76@2x.png"
Save-ResizedPng 167 "$iosBase\Icon-App-83.5x83.5@2x.png"

$sourceImage.Dispose()

Write-Host ""
Write-Host "=======================================" -ForegroundColor Green
Write-Host "  All icons updated successfully!" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green
Write-Host ""
Write-Host "Updated:" -ForegroundColor Cyan
Write-Host "  - Windows: app_icon.ico (taskbar, desktop)"
Write-Host "  - Android: ic_launcher.png (all densities)"
Write-Host "  - iOS: AppIcon (all sizes)"
Write-Host ""
Write-Host "Rebuild the app to see changes." -ForegroundColor Yellow
