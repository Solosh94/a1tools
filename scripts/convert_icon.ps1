Add-Type -AssemblyName System.Drawing

$sourcePath = 'H:\A1Chimney\a1_tools\assets\icons\app_icon.png'
$destPath = 'H:\A1Chimney\a1_tools\assets\icons\tray_icon.ico'

# Load source image
$sourceImage = [System.Drawing.Image]::FromFile($sourcePath)

# Create multiple sizes for ICO (16, 32, 48, 256)
$sizes = @(16, 32, 48, 256)
$icons = @()

# Create a memory stream to write the ICO
$ms = New-Object System.IO.MemoryStream

# ICO Header
$writer = New-Object System.IO.BinaryWriter($ms)
$writer.Write([Int16]0)           # Reserved
$writer.Write([Int16]1)           # Type (1 = ICO)
$writer.Write([Int16]$sizes.Count) # Number of images

# Calculate offset (header = 6 bytes, directory entries = 16 bytes each)
$offset = 6 + (16 * $sizes.Count)

# Store image data
$imageData = @()

foreach ($size in $sizes) {
    # Create resized bitmap
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $graphics = [System.Drawing.Graphics]::FromImage($bmp)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.DrawImage($sourceImage, 0, 0, $size, $size)
    $graphics.Dispose()

    # Convert to PNG bytes
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

    $writer.Write([byte]$(if ($size -eq 256) { 0 } else { $size }))  # Width
    $writer.Write([byte]$(if ($size -eq 256) { 0 } else { $size }))  # Height
    $writer.Write([byte]0)            # Color palette
    $writer.Write([byte]0)            # Reserved
    $writer.Write([Int16]1)           # Color planes
    $writer.Write([Int16]32)          # Bits per pixel
    $writer.Write([Int32]$bytes.Length)  # Size of image data
    $writer.Write([Int32]$offset)     # Offset to image data

    $offset += $bytes.Length
}

# Write image data
foreach ($data in $imageData) {
    $writer.Write($data[1])
}

$writer.Flush()

# Write to file
[System.IO.File]::WriteAllBytes($destPath, $ms.ToArray())

$writer.Dispose()
$ms.Dispose()
$sourceImage.Dispose()

Write-Host "tray_icon.ico created successfully with sizes: $($sizes -join ', ')px"
