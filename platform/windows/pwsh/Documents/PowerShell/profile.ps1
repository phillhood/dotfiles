# profile.ps1 - managed by stow-style links (~/Dev/phillhood/dotfiles, pwsh-windows)

$_pwshArgs = [Environment]::GetCommandLineArgs() | Select-Object -Skip 1
if (($_pwshArgs -match '^-(c|command|cwa|commandwithargs|f|file|e|ec|encodedcommand)$') -and -not ($_pwshArgs -match '^-noe')) {
  Remove-Variable _pwshArgs
  return
}
Remove-Variable _pwshArgs

$ESC = [char]27

# ---- PATH ----
foreach ($dir in "$HOME\.local\bin", "$HOME\.cargo\bin", "$HOME\go\bin", "$HOME\.bun\bin") {
  if ((Test-Path $dir) -and ($env:PATH -split ';') -notcontains $dir) { $env:PATH = "$dir;$env:PATH" }
}

# Get-Command walks every PATH dir per call (~150ms each with winget's dirs); index once instead.
$_exeIndex = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($dir in $env:PATH -split ';') {
  if (-not $dir -or -not [IO.Directory]::Exists($dir)) { continue }
  try {
    foreach ($f in [IO.Directory]::EnumerateFiles($dir)) {
      if ([IO.Path]::GetExtension($f) -in '.exe', '.cmd', '.bat', '.com') {
        [void]$_exeIndex.Add([IO.Path]::GetFileNameWithoutExtension($f))
      }
    }
  } catch {}
}
function Test-Command([string]$Name) { $_exeIndex.Contains($Name) }

$_interactive = $Host.UI.SupportsVirtualTerminal -and -not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected

# ---- Line editing ----
if ($_interactive) {
  Set-PSReadLineOption -EditMode Emacs -BellStyle None -HistoryNoDuplicates -MaximumHistoryCount 10000
  Set-PSReadLineOption -AddToHistoryHandler { param($line) -not $line.StartsWith(' ') }
  Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
  Set-PSReadLineKeyHandler -Chord Ctrl+p -Function HistorySearchBackward
  Set-PSReadLineKeyHandler -Chord Ctrl+n -Function HistorySearchForward
  Set-PSReadLineKeyHandler -Chord Alt+Enter -Function AddLine
  try {
    Set-PSReadLineOption -PredictionSource History -PredictionViewStyle InlineView
    Set-PSReadLineKeyHandler -Chord Ctrl+f -Function AcceptSuggestion
  } catch {}
}

# ---- Prompt ----
if (Test-Command starship) {
  Invoke-Expression (& starship init powershell)
  function Invoke-Starship-PreCommand {
    if ($global:_prompt_drawn) { [Console]::Write("`n") }
    $global:_prompt_drawn = $true
    [Console]::Write("$ESC[5 q")
  }
}
Remove-Item -Force Alias:clear -ErrorAction SilentlyContinue
function clear { Clear-Host; $global:_prompt_drawn = $false }

# ---- Shell integrations ----
if (Test-Command fnm) { fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression }
if (Test-Command uv) {
  $_uvComp = "$HOME\.cache\uv-completion.ps1"
  $_uvExe = (Get-Command uv -CommandType Application -TotalCount 1).Source
  if (-not (Test-Path $_uvComp) -or (Get-Item $_uvExe).LastWriteTime -gt (Get-Item $_uvComp).LastWriteTime) {
    New-Item -ItemType Directory -Force (Split-Path $_uvComp) | Out-Null
    uv generate-shell-completion powershell | Set-Content -Encoding utf8 $_uvComp
  }
  . $_uvComp
  Remove-Variable _uvComp, _uvExe
}
if ($_interactive -and (Test-Command fzf) -and
    ($env:PSModulePath -split ';' | Where-Object { $_ -and (Test-Path "$_\PSFzf") })) {
  Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Import-Module PSFzf; Invoke-FzfTabCompletion }
  Set-PSReadLineKeyHandler -Chord Ctrl+t -ScriptBlock { Import-Module PSFzf; Invoke-FzfPsReadlineHandlerProvider }
}
if (Test-Command atuin) { atuin init powershell --disable-up-arrow | Out-String | Invoke-Expression }
if (Test-Command direnv) { direnv hook pwsh | Out-String | Invoke-Expression }
if (Test-Command zoxide) { zoxide init powershell --cmd cd | Out-String | Invoke-Expression }

# ---- Aliases ----
Set-Alias c clear
function .. { Set-Location .. }
if (Test-Command eza) {
  Remove-Item -Force Alias:ls -ErrorAction SilentlyContinue
  function ls { eza --icons @args }
  function ll { eza -lb --icons --git @args }
  function la { eza -lba --icons --git @args }
  function lls { eza -lb --icons --git --sort=size --reverse @args }
  function las { eza -lba --icons --git --sort=size --reverse @args }
  function tree { eza --tree --icons @args }
}
if (Test-Command bat) {
  Remove-Item -Force Alias:cat -ErrorAction SilentlyContinue
  function cat { bat --paging=never @args }
}
if (Test-Command rg) { Set-Alias grep rg }
if (Test-Command nvim) { Set-Alias vim nvim }
if (Test-Command uv) {
  function py { uv run python @args }
  function pyr { uv run @args }
  function pip { uv pip @args }
}
function loadenv([string]$Path = '.env') {
  foreach ($line in Get-Content -LiteralPath $Path) {
    if ($line -match '^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$') {
      $name, $val = $Matches[1], $Matches[2]
      if ($val -match '^"(.*)"$' -or $val -match "^'(.*)'$") { $val = $Matches[1] }
      [Environment]::SetEnvironmentVariable($name, $val, 'Process')
    }
  }
}
function loadenv-staging { loadenv .env.staging }
# Kubernetes
if (Test-Command kubectl) { Set-Alias k kubectl }
if (Test-Command kubectx) { Set-Alias kctx kubectx }
if (Test-Command kubens) { Set-Alias kns kubens }

# ---- Environment ----
$env:SOPS_AGE_KEY_FILE = "$HOME\.age\dev.txt"
$env:FZF_DEFAULT_OPTS = "$env:FZF_DEFAULT_OPTS --walker-skip=.git,node_modules,target".Trim()
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'

# ---- Personal shell utils ----
$_utils = Join-Path $HOME '.config\powershell\utils'
if (Test-Path $_utils) {
  foreach ($file in Get-ChildItem -LiteralPath $_utils -Filter *.ps1 -File) { . $file.FullName }
}
Remove-Variable _utils
