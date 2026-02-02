param(
  # Where the outputs (installer, APK, latest.json) will be written
  [string]$OutputDir = 'H:\A1Chimney\a1_tools\installer\output',

  # Optional override if pubspec.yaml isn't bumped yet (e.g., -VersionOverride 1.0.8)
  [string]$VersionOverride,

  # Public base URL where you host downloads (no trailing slash)
  [string]$DownloadsBaseUrl = 'https://tools.a-1chimney.com/downloads',

  # Build targets (comma-separated): windows,android or just one
  [string]$Targets = 'windows,android',

  # Skip version bump (useful for rebuilding same version)
  [switch]$NoBump
)

$ErrorActionPreference = 'Stop'

# ============================================================
# VERSION BUMP FUNCTION
# ============================================================
function Bump-Version {
  param([string]$PubspecPath = ".\pubspec.yaml")

  $content = Get-Content -Raw -Path $PubspecPath
  $versionMatch = [regex]::Match($content, "version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)")

  if (-not $versionMatch.Success) {
    throw "Could not parse version from pubspec.yaml"
  }

  $major = [int]$versionMatch.Groups[1].Value
  $minor = [int]$versionMatch.Groups[2].Value
  $patch = [int]$versionMatch.Groups[3].Value
  $buildNum = [int]$versionMatch.Groups[4].Value

  $oldVersion = "$major.$minor.$patch+$buildNum"

  # Bump patch version by 1
  $patch++

  # Build number format: XYZZ (e.g., 3.8.94 -> 3894)
  $newBuildNum = ($major * 1000) + ($minor * 100) + $patch

  $newVersion = "$major.$minor.$patch+$newBuildNum"

  Write-Host ""
  Write-Host "==> Bumping version..." -ForegroundColor Cyan
  Write-Host "    Old: $oldVersion" -ForegroundColor Gray
  Write-Host "    New: $newVersion" -ForegroundColor Green

  # Replace version in pubspec.yaml
  $newContent = $content -replace "version:\s*\d+\.\d+\.\d+\+\d+", "version: $newVersion"
  Set-Content -Path $PubspecPath -Value $newContent -NoNewline

  return @{
    Version = "$major.$minor.$patch"
    BuildNumber = $newBuildNum
    FullVersion = $newVersion
  }
}

function Resolve-ISCC {
  $candidates = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
  )
  foreach ($p in $candidates) {
    if (Test-Path $p) { return $p }
  }
  throw "Inno Setup 6 not found. Install from https://jrsoftware.org/isinfo.php"
}

# --- Parse targets ---
$buildWindows = $Targets -match 'windows'
$buildAndroid = $Targets -match 'android'

if (-not $buildWindows -and -not $buildAndroid) {
  throw "No valid targets specified. Use -Targets 'windows,android' or 'windows' or 'android'"
}

# --- Paths (run from repo root: H:\A1Chimney\a1_tools\) ---
$IssPath = "installer\a1-tools.iss"

# --- Version bump and read ---
if ($VersionOverride) {
  # Use override version if provided
  $Version = $VersionOverride
  $pub = Get-Content -Raw -Path ".\pubspec.yaml"
  $buildMatch = [regex]::Match($pub, "version:\s*\d+\.\d+\.\d+\+(\d+)")
  $BuildNumber = if ($buildMatch.Success) { $buildMatch.Groups[1].Value } else { "1" }
} elseif ($NoBump) {
  # Read current version without bumping
  $pub = Get-Content -Raw -Path ".\pubspec.yaml"
  $match = [regex]::Match($pub, "version:\s*(\d+\.\d+\.\d+)(\+\d+)?")
  if (-not $match.Success) { throw "Could not read version from pubspec.yaml" }
  $Version = $match.Groups[1].Value
  $buildMatch = [regex]::Match($pub, "version:\s*\d+\.\d+\.\d+\+(\d+)")
  $BuildNumber = if ($buildMatch.Success) { $buildMatch.Groups[1].Value } else { "1" }
  Write-Host ""
  Write-Host "==> Skipping version bump (using current: $Version+$BuildNumber)" -ForegroundColor Yellow
} else {
  # Bump version automatically
  $versionInfo = Bump-Version
  $Version = $versionInfo.Version
  $BuildNumber = $versionInfo.BuildNumber
}

Write-Host ""
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "  A1 Tools Release Builder v$Version" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Targets: " -NoNewline
if ($buildWindows) { Write-Host "Windows " -NoNewline -ForegroundColor Green }
if ($buildAndroid) { Write-Host "Android " -NoNewline -ForegroundColor Green }
Write-Host ""
Write-Host ""

# --- Ensure output dir exists ---
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

# --- Clean and get dependencies ---
Write-Host "==> Cleaning and fetching dependencies..." -ForegroundColor Cyan
flutter clean
flutter pub get

# Initialize manifest object
$manifestObj = [ordered]@{
  latest_version = $Version
  generated_at   = (Get-Date).ToString("s")
}

# ============================================================
# WINDOWS BUILD
# ============================================================
if ($buildWindows) {
  Write-Host ""
  Write-Host "==> Building Windows Release..." -ForegroundColor Cyan
  Write-Host "    Install location: %LocalAppData%\A1 Tools (no UAC required)" -ForegroundColor Gray

  if (-not (Test-Path $IssPath)) { throw "ISS not found: $IssPath" }

  # Flutter build for Windows
  # Note: CMake dev warnings from webview_windows plugin are expected and harmless
  flutter build windows --release --dart-define=APP_VERSION=$Version

  $ReleaseDir = "build\windows\x64\runner\Release"
  if (-not (Test-Path $ReleaseDir)) { throw "Release dir not found: $ReleaseDir" }

  # Remove WebView2Runtime folder to reduce installer size (~200MB savings)
  # The app will use system's Evergreen WebView2 (pre-installed on Windows 10/11)
  $webview2Dir = Join-Path $ReleaseDir "WebView2Runtime"
  if (Test-Path $webview2Dir) {
    Write-Host "    Removing bundled WebView2Runtime (using system WebView2 instead)..." -ForegroundColor Gray
    Remove-Item -Recurse -Force $webview2Dir
  }

  # Detect the main EXE
  $exe = Get-ChildItem "$ReleaseDir\*.exe" | Select-Object -First 1
  if (-not $exe) { throw "No EXE found in $ReleaseDir" }
  $ExeName = $exe.Name
  Write-Host "    Detected EXE: $ExeName" -ForegroundColor Gray

  # --- Inno Setup compile ---
  $Inno = Resolve-ISCC
  Write-Host "    Using ISCC: $Inno" -ForegroundColor Gray

  $isccArgs = @(
    "/DMyAppVersion=$Version",
    "/DMyAppExeName=$ExeName",
    "$IssPath"
  )

  Write-Host "==> Compiling Windows installer..." -ForegroundColor Cyan
  $proc = Start-Process -FilePath $Inno -ArgumentList $isccArgs -Wait -PassThru
  if ($proc.ExitCode -ne 0) {
    throw "ISCC failed with exit code $($proc.ExitCode). Check the console output."
  }

  $installerName = "A1-Tools-Setup-$Version.exe"
  $installerPath = Join-Path $OutputDir $installerName

  Write-Host "    Windows installer created: $installerName" -ForegroundColor Green

  # --- Code Sign the installer ---
  Write-Host "==> Signing installer with EV certificate..." -ForegroundColor Cyan

  # Find signtool.exe dynamically from Windows SDK
  $signtool = $null

  # Search for the latest SDK version's x64 signtool
  $sdkBinPath = "${env:ProgramFiles(x86)}\Windows Kits\10\bin"
  if (Test-Path $sdkBinPath) {
    # Get all version folders, sort descending, find first with signtool
    $versionFolders = Get-ChildItem -Path $sdkBinPath -Directory |
      Where-Object { $_.Name -match '^\d+\.\d+\.\d+\.\d+$' } |
      Sort-Object { [version]$_.Name } -Descending

    foreach ($folder in $versionFolders) {
      $candidate = Join-Path $folder.FullName "x64\signtool.exe"
      if (Test-Path $candidate) {
        $signtool = $candidate
        break
      }
    }
  }

  # Fallback to known paths if dynamic search failed
  if (-not $signtool) {
    $fallbackPaths = @(
      "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.26100.0\x64\signtool.exe",
      "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.22621.0\x64\signtool.exe",
      "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.19041.0\x64\signtool.exe"
    )
    foreach ($path in $fallbackPaths) {
      if (Test-Path $path) {
        $signtool = $path
        break
      }
    }
  }

  if (-not $signtool) {
    Write-Host "    WARNING: signtool.exe not found. Install Windows SDK." -ForegroundColor Yellow
    Write-Host "    Installer will be UNSIGNED." -ForegroundColor Yellow
  } else {
    Write-Host "    Using signtool: $signtool" -ForegroundColor Gray

    # Sign with SHA-256 and RFC 3161 timestamp (DigiCert timestamp server)
    # The /a flag auto-selects the best certificate from the token
    $signArgs = @(
      "sign",
      "/tr", "http://timestamp.digicert.com",
      "/td", "sha256",
      "/fd", "sha256",
      "/a",
      "`"$installerPath`""
    )

    Write-Host "    Make sure your YubiKey/token is plugged in..." -ForegroundColor Yellow

    $signProc = Start-Process -FilePath $signtool -ArgumentList $signArgs -Wait -PassThru -NoNewWindow

    if ($signProc.ExitCode -eq 0) {
      Write-Host "    Installer signed successfully!" -ForegroundColor Green

      # Verify the signature
      Write-Host "    Verifying signature..." -ForegroundColor Gray
      $verifyArgs = @("verify", "/pa", "`"$installerPath`"")
      $verifyProc = Start-Process -FilePath $signtool -ArgumentList $verifyArgs -Wait -PassThru -NoNewWindow

      if ($verifyProc.ExitCode -eq 0) {
        Write-Host "    Signature verified!" -ForegroundColor Green
      } else {
        Write-Host "    WARNING: Signature verification failed." -ForegroundColor Yellow
      }
    } else {
      Write-Host "    WARNING: Code signing failed (exit code: $($signProc.ExitCode))." -ForegroundColor Yellow
      Write-Host "    Check that your YubiKey is inserted and PIN is correct." -ForegroundColor Yellow
      Write-Host "    Installer will be UNSIGNED." -ForegroundColor Yellow
    }
  }

  # Add Windows info to manifest
  $manifestObj['windows'] = [ordered]@{
    version      = $Version
    download_url = "$DownloadsBaseUrl/$installerName"
    filename     = $installerName
    size_bytes   = (Get-Item $installerPath).Length
  }
  
  # Keep legacy fields for backward compatibility
  $manifestObj['download_url'] = "$DownloadsBaseUrl/$installerName"
}

# ============================================================
# ANDROID BUILD (App Bundle for Google Play)
# ============================================================
if ($buildAndroid) {
  Write-Host ""
  Write-Host "==> Building Android App Bundle (AAB)..." -ForegroundColor Cyan
  Write-Host "    AAB is required for Google Play Store uploads" -ForegroundColor Gray

  # Flutter build for Android App Bundle (required by Google Play)
  flutter build appbundle --release --dart-define=APP_VERSION=$Version

  $AabSourcePath = "build\app\outputs\bundle\release\app-release.aab"
  if (-not (Test-Path $AabSourcePath)) {
    throw "AAB not found: $AabSourcePath. Make sure Android SDK is configured and signing is set up."
  }

  # Rename AAB to include version
  $aabName = "A1-Tools-$Version.aab"
  $aabDestPath = Join-Path $OutputDir $aabName

  Copy-Item -Path $AabSourcePath -Destination $aabDestPath -Force

  Write-Host "    Android App Bundle created: $aabName" -ForegroundColor Green

  # Add Android info to manifest
  $manifestObj['android'] = [ordered]@{
    version       = $Version
    version_code  = [int]$BuildNumber
    download_url  = "$DownloadsBaseUrl/$aabName"
    filename      = $aabName
    size_bytes    = (Get-Item $aabDestPath).Length
  }
}

# ============================================================
# WRITE MANIFEST (latest.json)
# ============================================================
$manifestPath = Join-Path $OutputDir 'latest.json'
$manifestJson = ($manifestObj | ConvertTo-Json -Depth 5)
$manifestJson | Set-Content -Path $manifestPath -Encoding UTF8

Write-Host ""
Write-Host "=======================================" -ForegroundColor Green
Write-Host "  Build Complete!" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green
Write-Host ""
Write-Host "Output files in: $OutputDir" -ForegroundColor Yellow
Write-Host ""

if ($buildWindows) {
  Write-Host "  Windows:" -ForegroundColor Cyan
  Write-Host "    - A1-Tools-Setup-$Version.exe"
}

if ($buildAndroid) {
  Write-Host "  Android:" -ForegroundColor Cyan
  Write-Host "    - A1-Tools-$Version.aab (upload to Google Play)"
}

Write-Host ""
Write-Host "  Manifest:" -ForegroundColor Cyan
Write-Host "    - latest.json"
Write-Host ""

# Show manifest contents
Write-Host "Manifest contents:" -ForegroundColor Gray
Write-Host $manifestJson -ForegroundColor DarkGray
Write-Host ""

Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1) Upload all files to /downloads on your server:"
Get-ChildItem $OutputDir | ForEach-Object { Write-Host "       $($_.Name)" }
Write-Host ""
Write-Host "  2) Verify in browser:"
Write-Host "       $DownloadsBaseUrl/latest.json"
if ($buildWindows) {
  Write-Host "       $DownloadsBaseUrl/A1-Tools-Setup-$Version.exe"
}
if ($buildAndroid) {
  Write-Host "       $DownloadsBaseUrl/A1-Tools-$Version.aab (upload to Google Play)"
}
Write-Host ""
