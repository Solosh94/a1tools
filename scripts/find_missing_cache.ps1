$apiPath = 'H:\A1Chimney\a1_tools\api'
$phpFiles = Get-ChildItem -Path $apiPath -Filter '*.php' -Recurse

Write-Host "PHP files WITHOUT cache headers:" -ForegroundColor Yellow
foreach ($file in $phpFiles) {
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    if ($content -and $content -notmatch 'Cache-Control') {
        Write-Host "  $($file.FullName)"
    }
}
