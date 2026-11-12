# Installs the Android build toolchain (JDK 17 + Android SDK) into .toolchain\
# so an APK can be produced without touching the rest of the system.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$tc = Join-Path $root '.toolchain'
$logs = Join-Path $root '.logs'
New-Item -ItemType Directory -Path $tc, $logs -Force | Out-Null

function Step($m) { Write-Host "==> $m" -ForegroundColor Cyan }

# ── 1. JDK 17 ────────────────────────────────────────────────
$jdkDir = Join-Path $tc 'jdk'
if (-not (Test-Path (Join-Path $jdkDir 'bin\java.exe'))) {
  Step 'Downloading Temurin JDK 17…'
  $zip = Join-Path $tc 'jdk.zip'
  & curl.exe -L --fail --retry 3 --retry-delay 3 --connect-timeout 30 --max-time 900 `
    -o $zip 'https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse'
  if (-not (Test-Path $zip)) { throw 'JDK download failed' }
  Step 'Extracting JDK…'
  New-Item -ItemType Directory -Path $jdkDir -Force | Out-Null
  Expand-Archive -Path $zip -DestinationPath $jdkDir -Force
  Remove-Item $zip -Force
  # the archive contains a single versioned folder
  $inner = Get-ChildItem $jdkDir -Directory | Select-Object -First 1
  if ($inner) {
    Get-ChildItem $inner.FullName | Move-Item -Destination $jdkDir -Force
    Remove-Item $inner.FullName -Recurse -Force -ErrorAction SilentlyContinue
  }
}
$java = Join-Path $jdkDir 'bin\java.exe'
if (-not (Test-Path $java)) { throw "JDK extraction failed" }
$env:JAVA_HOME = $jdkDir
# java prints its version to stderr — don't let that abort the script
$ErrorActionPreference = 'Continue'
$javaVersion = (& $java -version 2>&1 | Out-String).Trim() -split "`n" | Select-Object -First 1
$ErrorActionPreference = 'Stop'
Step "JDK ready: $javaVersion"

# ── 2. Android command-line tools ────────────────────────────
$sdk = Join-Path $tc 'android-sdk'
$cmdline = Join-Path $sdk 'cmdline-tools\latest'
if (-not (Test-Path (Join-Path $cmdline 'bin\sdkmanager.bat'))) {
  Step 'Downloading Android command-line tools…'
  $zip = Join-Path $tc 'cmdtools.zip'
  $url = 'https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip'
  # dl.google.com resets long connections — resume until the file is complete.
  # curl's progress output goes to stderr, so it is silenced to keep
  # PowerShell from treating it as a terminating error.
  for ($attempt = 1; $attempt -le 15; $attempt++) {
    $ErrorActionPreference = 'Continue'
    & curl.exe -sS -L --fail --connect-timeout 30 --max-time 420 --speed-limit 2000 --speed-time 45 `
      -C - -o $zip $url 2>$null
    $ErrorActionPreference = 'Stop'
    $size = if (Test-Path $zip) { [math]::Round((Get-Item $zip).Length / 1MB, 1) } else { 0 }
    Write-Host "   attempt $attempt → $size MB of ~146 MB"
    if ($size -gt 140) { break }
    Start-Sleep -Seconds 3
  }
  if (-not (Test-Path $zip) -or (Get-Item $zip).Length -lt 140MB) { throw 'command-line tools download failed' }
  Step 'Extracting…'
  New-Item -ItemType Directory -Path (Join-Path $sdk 'cmdline-tools') -Force | Out-Null
  Expand-Archive -Path $zip -DestinationPath (Join-Path $sdk 'cmdline-tools') -Force
  Remove-Item $zip -Force
  if (Test-Path (Join-Path $sdk 'cmdline-tools\cmdline-tools')) {
    Move-Item (Join-Path $sdk 'cmdline-tools\cmdline-tools') $cmdline -Force
  }
}
$sdkmanager = Join-Path $cmdline 'bin\sdkmanager.bat'
if (-not (Test-Path $sdkmanager)) { throw "sdkmanager not found at $sdkmanager" }
Step 'sdkmanager ready'

$env:ANDROID_HOME = $sdk
$env:ANDROID_SDK_ROOT = $sdk

# ── 3. licences ──────────────────────────────────────────────
Step 'Accepting SDK licences…'
$yes = 1..40 | ForEach-Object { 'y' }
$yes | & $sdkmanager --sdk_root=$sdk --licenses 2>&1 | Out-Null

# ── 4. platform + build tools ────────────────────────────────
Step 'Installing platforms;android-34, build-tools;34.0.0, platform-tools…'
& $sdkmanager --sdk_root=$sdk 'platform-tools' 'platforms;android-34' 'build-tools;34.0.0' 2>&1 |
  Select-Object -Last 12 | ForEach-Object { "   $_" }

# ── 5. verify ────────────────────────────────────────────────
$buildTools = Get-ChildItem (Join-Path $sdk 'build-tools') -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
$apksigner = if ($buildTools) { Join-Path $buildTools.FullName 'apksigner.bat' } else { $null }
$zipalign = if ($buildTools) { Join-Path $buildTools.FullName 'zipalign.exe' } else { $null }
Write-Host ''
Write-Host "Toolchain summary" -ForegroundColor Green
Write-Host "  JAVA_HOME      = $jdkDir"
Write-Host "  ANDROID_HOME   = $sdk"
Write-Host "  sdkmanager     = $(if (Test-Path $sdkmanager) { 'ok' } else { 'MISSING' })"
Write-Host "  adb            = $(if (Test-Path (Join-Path $sdk 'platform-tools\adb.exe')) { 'ok' } else { 'MISSING' })"
Write-Host "  apksigner      = $(if ($apksigner -and (Test-Path $apksigner)) { 'ok' } else { 'MISSING' })"
Write-Host "  zipalign       = $(if ($zipalign -and (Test-Path $zipalign)) { 'ok' } else { 'MISSING' })"
Write-Host ''
Write-Host 'Toolchain ready.' -ForegroundColor Green
