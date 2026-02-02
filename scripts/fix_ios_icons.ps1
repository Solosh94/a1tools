Add-Type -AssemblyName System.Drawing

$sourcePath = 'H:\A1Chimney\a1_tools\assets\icons\app_icon.png'
$sourceImage = [System.Drawing.Image]::FromFile($sourcePath)

Write-Host "Fixing iOS icons - removing alpha channel..." -ForegroundColor Cyan

# Function to create PNG without alpha (solid background)
function Save-FlattenedPng {
    param($size, $destPath, $bgColor = [System.Drawing.Color]::Black)

    # Create bitmap with no alpha channel (RGB only)
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bmp)

    # Fill with solid background color first
    $graphics.Clear($bgColor)

    # High quality rendering
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver

    # Draw the source image on top
    $graphics.DrawImage($sourceImage, 0, 0, $size, $size)
    $graphics.Dispose()

    # Save as PNG
    $bmp.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "  Created: $destPath" -ForegroundColor Gray
}

$iosBase = 'H:\A1Chimney\a1_tools\ios\Runner\Assets.xcassets\AppIcon.appiconset'

# Use black background (matches your dark icon)
$bg = [System.Drawing.Color]::FromArgb(255, 30, 30, 30)

# Regenerate all iOS icons without transparency
Save-FlattenedPng 1024 "$iosBase\Icon-App-1024x1024@1x.png" $bg
Save-FlattenedPng 20 "$iosBase\Icon-App-20x20@1x.png" $bg
Save-FlattenedPng 40 "$iosBase\Icon-App-20x20@2x.png" $bg
Save-FlattenedPng 60 "$iosBase\Icon-App-20x20@3x.png" $bg
Save-FlattenedPng 29 "$iosBase\Icon-App-29x29@1x.png" $bg
Save-FlattenedPng 58 "$iosBase\Icon-App-29x29@2x.png" $bg
Save-FlattenedPng 87 "$iosBase\Icon-App-29x29@3x.png" $bg
Save-FlattenedPng 40 "$iosBase\Icon-App-40x40@1x.png" $bg
Save-FlattenedPng 80 "$iosBase\Icon-App-40x40@2x.png" $bg
Save-FlattenedPng 120 "$iosBase\Icon-App-40x40@3x.png" $bg
Save-FlattenedPng 50 "$iosBase\Icon-App-50x50@1x.png" $bg
Save-FlattenedPng 100 "$iosBase\Icon-App-50x50@2x.png" $bg
Save-FlattenedPng 57 "$iosBase\Icon-App-57x57@1x.png" $bg
Save-FlattenedPng 114 "$iosBase\Icon-App-57x57@2x.png" $bg
Save-FlattenedPng 120 "$iosBase\Icon-App-60x60@2x.png" $bg
Save-FlattenedPng 180 "$iosBase\Icon-App-60x60@3x.png" $bg
Save-FlattenedPng 72 "$iosBase\Icon-App-72x72@1x.png" $bg
Save-FlattenedPng 144 "$iosBase\Icon-App-72x72@2x.png" $bg
Save-FlattenedPng 76 "$iosBase\Icon-App-76x76@1x.png" $bg
Save-FlattenedPng 152 "$iosBase\Icon-App-76x76@2x.png" $bg
Save-FlattenedPng 167 "$iosBase\Icon-App-83.5x83.5@2x.png" $bg

$sourceImage.Dispose()

Write-Host ""
Write-Host "Done! iOS icons regenerated without alpha channel." -ForegroundColor Green
Write-Host "Rebuild the iOS app and resubmit to App Store." -ForegroundColor Yellow
