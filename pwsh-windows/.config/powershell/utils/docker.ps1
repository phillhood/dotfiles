function dockstats {
  $fmt = 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}\t{{.PIDs}}'
  while ($true) {
    $stats = docker stats --no-stream --format $fmt
    Clear-Host
    $stats | Select-Object -First 1
    $stats | Select-Object -Skip 1 | Sort-Object
    Start-Sleep -Seconds 1
  }
}

# Color-coded logs for all running containers. Replicas (web-1, web-2) share a
# colour; with a prefix, every container whose name starts with it shares one.
function docklogs([string]$Prefix) {
  $esc = [char]27
  $colors = 31, 32, 33, 34, 35, 36, 37, 91, 92, 93, 94, 95, 96
  $colorOf = @{}
  $next = 0
  $jobs = @()
  foreach ($c in @(docker ps --format '{{.Names}}')) {
    if (-not $c) { continue }
    $group = if ($Prefix -and $c.StartsWith($Prefix)) { $Prefix } else { $c -replace '[-_]\d+$', '' }
    if (-not $colorOf.ContainsKey($group)) {
      $colorOf[$group] = $colors[$next]
      $next = ($next + 1) % $colors.Count
    }
    $tag = "$esc[$($colorOf[$group])m$c$esc[0m --- "
    $jobs += Start-ThreadJob -ArgumentList $c, $tag {
      param($name, $tag)
      docker logs -f $name 2>&1 | ForEach-Object { "$tag$_" }
    }
  }
  if (-not $jobs) { Write-Error 'docklogs: no running containers'; return }
  try {
    while ($true) { $jobs | Receive-Job; Start-Sleep -Milliseconds 200 }
  } finally {
    $jobs | Stop-Job -PassThru | Remove-Job -Force
  }
}
