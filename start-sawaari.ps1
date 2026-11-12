<#
  Sawaari — one-click launcher.
  Starts PostgreSQL (if needed), the API and the web app, then opens the browser.

  Usage:  Right-click this file → "Run with PowerShell"
          or from a terminal:  powershell -ExecutionPolicy Bypass -File .\start-sawaari.ps1
#>
param(
  [switch]$NoBrowser,
  [switch]$NoPause
)

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$serverDir = Join-Path $root 'server'
$webDir = Join-Path $root 'web'
$logDir = Join-Path $root '.logs'

function Say($msg, $color = 'Gray') { Write-Host $msg -ForegroundColor $color }
function Test-Port($port) {
  (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1) -ne $null
}

New-Item -ItemType Directory -Path $logDir -Force | Out-Null

# ── 1. database ───────────────────────────────────────────────
Say 'Checking PostgreSQL…'
$pg = Get-Service -Name 'postgresql-x64-17' -ErrorAction SilentlyContinue
if (-not $pg) {
  $pg = Get-Service -Name 'postgresql*' -ErrorAction SilentlyContinue | Select-Object -First 1
}
if ($pg) {
  if ($pg.Status -ne 'Running') {
    Say "  starting $($pg.Name)…"
    Start-Service $pg.Name -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
  }
  Say "  PostgreSQL: $((Get-Service $pg.Name).Status)" 'Green'
} else {
  Say '  ! PostgreSQL service not found — install it or start your database manually.' 'Yellow'
}

# ── 2. API ────────────────────────────────────────────────────
if (Test-Port 4000) {
  Say '  API already running on http://localhost:4000' 'Green'; $apiOk = $true
} else {
  Say '  starting the API…'
  $envFile = Join-Path $serverDir '.env'
  if (-not (Test-Path $envFile)) {
    Say '  ! server\.env is missing — copy server\.env.example to server\.env and set JWT_SECRET + OTP_PEPPER' 'Yellow'
  }
  Start-Process -FilePath 'npm.cmd' -ArgumentList 'start' -WorkingDirectory $serverDir `
    -RedirectStandardOutput (Join-Path $logDir 'api.log') `
    -RedirectStandardError (Join-Path $logDir 'api.err.log') -NoNewWindow
  for ($i = 0; $i -lt 20; $i++) { Start-Sleep -Seconds 1; if (Test-Port 4000) { break } }
  if (Test-Port 4000) { Say '  API started on http://localhost:4000' 'Green'; $apiOk = $true }
  else { Say "  ! API did not start — see .logs\api.err.log" 'Red'; $apiOk = $false }
}

# ── 3. web app ────────────────────────────────────────────────
if (Test-Port 5173) {
  Say '  Web app already running on http://localhost:5173' 'Green'; $webOk = $true
} else {
  Say '  starting the web app…'
  if (-not (Test-Path (Join-Path $webDir 'node_modules'))) {
    Say '  installing web dependencies (first run only)…'
    Push-Location $webDir; npm install --silent; Pop-Location
  }
  Start-Process -FilePath 'npm.cmd' -ArgumentList 'run', 'dev' -WorkingDirectory $webDir `
    -RedirectStandardOutput (Join-Path $logDir 'web.log') `
    -RedirectStandardError (Join-Path $logDir 'web.err.log') -NoNewWindow
  for ($i = 0; $i -lt 25; $i++) { Start-Sleep -Seconds 1; if (Test-Port 5173) { break } }
  if (Test-Port 5173) { Say '  Web app started on http://localhost:5173' 'Green'; $webOk = $true }
  else { Say "  ! Web app did not start — see .logs\web.err.log" 'Red'; $webOk = $false }
}

# ── 4. open the browser ───────────────────────────────────────
if (-not $NoBrowser) {
  Start-Sleep -Seconds 1
  Start-Process 'http://localhost:5173'
}

Say ''
if ($apiOk -and $webOk) {
  Say '  Sawaari is ready.' 'Cyan'
} else {
  Say '  Sawaari did not start cleanly — check .logs\ for details.' 'Red'
}
Say '    Rider / driver app : http://localhost:5173'
Say '    Admin console      : http://localhost:5173/admin-login'
Say ''
Say '  Super admin password: server\.env  →  SUPER_ADMIN_PASSWORD'
Say '  2FA secret          : server\backups\superadmin-credentials.txt'
Say ''
if (-not $NoPause) {
  Say '  Press Enter to close this window (the apps keep running).' 'DarkGray'
  $null = Read-Host
}
