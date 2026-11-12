<#
  Sawaari — stop the app (API + web dev server).
  PostgreSQL is left running; it is a Windows service that other tools may use.
#>
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
function Say($msg, $color = 'Gray') { Write-Host $msg -ForegroundColor $color }

foreach ($port in @(4000, 5173)) {
  $conns = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
  if ($conns) {
    $procIds = $conns | Select-Object -ExpandProperty OwningProcess -Unique
    foreach ($procId in $procIds) {
      $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
      if ($proc -and $proc.ProcessName -eq 'node') {
        Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
        Say "stopped $port (pid $procId)"
      }
    }
  } else {
    Say "port $port was not running"
  }
}

# clean up any npm wrapper processes
Get-CimInstance Win32_Process -Filter "Name='node.exe'" -ErrorAction SilentlyContinue |
  Where-Object { $_.CommandLine -match 'src/index.js|vite' } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue; Say "stopped node pid $($_.ProcessId)" }

Say ''
Say 'Sawaari stopped. PostgreSQL is still running (Windows service).' 'Cyan'
