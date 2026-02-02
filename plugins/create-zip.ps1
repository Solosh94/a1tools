Add-Type -AssemblyName System.IO.Compression.FileSystem

$sourceDir = 'H:/A1Chimney/a1_tools/plugins/a1-tools'
$zipPath = 'H:/A1Chimney/a1_tools/plugins/a1-tools-1.3.1.zip'
$folderName = 'a1-tools'

if (Test-Path $zipPath) { Remove-Item $zipPath }

$zip = [System.IO.Compression.ZipFile]::Open($zipPath, 'Create')

Get-ChildItem -Path $sourceDir -Recurse -File | ForEach-Object {
    $fullPath = $_.FullName
    $relativePath = $fullPath.Substring($sourceDir.Length)
    $entryPath = $folderName + $relativePath.Replace('\', '/')
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $fullPath, $entryPath) | Out-Null
    Write-Host "Added: $entryPath"
}

$zip.Dispose()
Write-Host 'Zip created successfully!'
