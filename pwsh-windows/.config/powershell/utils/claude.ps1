# One-off question: subscription auth, but no settings, hooks, plugins or MCP servers.
function ask {
  $prompt = $args -join ' '
  $claudeArgs = @(
    '-p', '--setting-sources', '',
    '--strict-mcp-config', '--mcp-config', '{"mcpServers":{}}',
    '--model', 'haiku', $prompt
  )
  if (-not (Get-Command Start-ThreadJob -ErrorAction SilentlyContinue)) {
    claude @claudeArgs
    return
  }
  $frames = 0x280B, 0x2819, 0x2839, 0x2838, 0x283C, 0x2834, 0x2826, 0x2827, 0x2807, 0x280F | ForEach-Object { [string][char]$_ }
  $esc = [char]27
  $job = Start-ThreadJob -ArgumentList (, $claudeArgs) {
    param($a)
    $out = & claude @a 2>&1 | Out-String
    [pscustomobject]@{ Out = $out; Code = $LASTEXITCODE }
  }
  try {
    [Console]::Error.Write("$esc[?25l")
    $i = 0
    while ($job.State -eq 'Running' -or $job.State -eq 'NotStarted') {
      [Console]::Error.Write("`r $($frames[$i])")
      $i = ($i + 1) % $frames.Count
      Start-Sleep -Milliseconds 80
    }
    $result = Receive-Job $job -Wait
  } finally {
    [Console]::Error.Write("`r$esc[K$esc[?25h")
    Remove-Job $job -Force -ErrorAction SilentlyContinue
  }
  [Console]::Error.WriteLine()
  $result.Out.TrimEnd()
  $global:LASTEXITCODE = $result.Code
}
