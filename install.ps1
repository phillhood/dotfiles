#Requires -Version 5.1
<#
.SYNOPSIS
  Windows counterpart to the Makefile: symlink stow packages into $HOME.
.DESCRIPTION
  Each package mirrors $HOME, as with stow. A leading Documents\ maps to the real
  Documents folder. Directories are always created as real directories and only files
  are linked, matching stow --no-folding. Installs no software.
.EXAMPLE
  .\install.ps1                      # link every Windows package
  .\install.ps1 -Packages git,bat    # link only these
  .\install.ps1 -List                # print the Windows packages from packages.conf
  .\install.ps1 -Unlink              # remove links pointing into this repo
  .\install.ps1 -Adopt               # move existing real files into the repo, then link
#>
[CmdletBinding(DefaultParameterSetName = 'Link')]
param(
  [string[]]$Packages,
  [string]$Target = $HOME,
  [Parameter(ParameterSetName = 'Unlink')][switch]$Unlink,
  [Parameter(ParameterSetName = 'Link')][switch]$Adopt,
  [switch]$List
)

$ErrorActionPreference = 'Stop'

$Repo = $PSScriptRoot

if (-not $Packages) {
  $Packages = foreach ($line in Get-Content -LiteralPath (Join-Path $Repo 'packages.conf')) {
    $fields = -split $line
    if ($fields.Count -gt 1 -and -not $fields[0].StartsWith('#') -and ($fields[1..($fields.Count - 1)] -contains 'windows')) { $fields[0] }
  }
}
if ($List) { $Packages; exit 0 }

$Target = [IO.Path]::GetFullPath($Target).TrimEnd('\')
$IsHome = $Target -eq [IO.Path]::GetFullPath($HOME).TrimEnd('\')
$Documents = if ($IsHome) { [Environment]::GetFolderPath('MyDocuments') } else { Join-Path $Target 'Documents' }
$StowIgnore = '.stow-local-ignore', '.gitignore', 'README.md', 'LICENSE', 'COPYING'

function Resolve-Target([string]$Rel) {
  if ($Rel -like 'Documents\*') { return Join-Path $Documents $Rel.Substring('Documents\'.Length) }
  Join-Path $Target $Rel
}

# Test-Path and Get-Item miss dangling links on Windows PowerShell; enumeration does not.
function Get-Existing([string]$Path) {
  $parent = Split-Path $Path -Parent
  if (-not (Test-Path -LiteralPath $parent)) { return $null }
  $leaf = Split-Path $Path -Leaf
  Get-ChildItem -LiteralPath $parent -Force | Where-Object Name -eq $leaf
}

function Get-LinkTarget($Item) {
  if (-not $Item -or $Item.LinkType -ne 'SymbolicLink') { return }
  $t = @($Item.Target)[0]
  if ($t -like 'UNC\*') { $t = '\\' + $t.Substring(4) }
  $t
}

# cmd's mklink honours Developer Mode's unprivileged symlinks; New-Item does not on 5.1.
function New-Link([string]$Link, [string]$Source) {
  $out = cmd /c ('mklink "{0}" "{1}" 2>&1' -f $Link, $Source)
  if ($LASTEXITCODE) { throw "mklink failed for ${Link}: $out" }
}

function Test-SymlinkCapable {
  $probe = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-probe-' + [guid]::NewGuid())
  Set-Content -LiteralPath "$probe.src" -Value ''
  cmd /c ('mklink "{0}" "{1}" >nul 2>&1' -f $probe, "$probe.src")
  $ok = $LASTEXITCODE -eq 0
  Remove-Item -LiteralPath $probe, "$probe.src" -Force -ErrorAction SilentlyContinue
  $ok
}

function Install-SshConfig {
  $sshDir = Join-Path $Target '.ssh'
  New-Item -ItemType Directory -Force $sshDir | Out-Null
  $cfg = Join-Path $sshDir 'config'
  $cur = Get-Existing $cfg
  if (-not $cur) {
    Copy-Item -LiteralPath (Join-Path $Repo 'tools\canonical\.ssh\config') $cfg
    Write-Host 'ssh-config: installed the skeleton'
  } elseif (Get-LinkTarget $cur) {
    Write-Warning 'ssh-config: ~/.ssh/config is a symlink; remove it and re-run'
  } else {
    Write-Host 'ssh-config: ~/.ssh/config already a real file, left untouched'
  }
  if ((Test-Path -LiteralPath $cfg) -and -not (Select-String -LiteralPath $cfg -SimpleMatch 'Include ~/.ssh/config.d/*.conf' -Quiet)) {
    Write-Warning "ssh-config: no 'Include ~/.ssh/config.d/*.conf' line, tracked hosts will not load"
  }
}

function Set-XdgConfigHome {
  $want = Join-Path $HOME '.config'
  $have = [Environment]::GetEnvironmentVariable('XDG_CONFIG_HOME', 'User')
  if (-not $have) {
    [Environment]::SetEnvironmentVariable('XDG_CONFIG_HOME', $want, 'User')
    $env:XDG_CONFIG_HOME = $want
    Write-Host "env: set XDG_CONFIG_HOME=$want for this user (open a new shell to pick it up)"
  } elseif ($have -ne $want) {
    Write-Warning "env: XDG_CONFIG_HOME is $have, packages expect $want"
  }
}

if (-not $Unlink) {
  if (-not (Test-SymlinkCapable)) {
    throw 'Cannot create symlinks. Turn on Developer Mode (Settings > System > For developers) or run elevated.'
  }
  if ($IsHome) { Set-XdgConfigHome }
  if ($Packages -contains 'ssh') { Install-SshConfig }
}

$conflicts = 0
foreach ($pkg in $Packages) {
  $root = Join-Path $Repo $pkg
  if (-not (Test-Path -LiteralPath $root -PathType Container)) { Write-Warning "no such package: $pkg"; continue }

  foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File -Force) {
    if ($StowIgnore -contains $file.Name) { continue }
    $src = $file.FullName
    $dst = Resolve-Target $src.Substring($root.Length + 1)
    $cur = Get-Existing $dst
    $curTarget = Get-LinkTarget $cur

    if ($Unlink) {
      if ($curTarget -eq $src) { Remove-Item -LiteralPath $dst -Force; Write-Host "unlink $dst" }
      continue
    }

    if ($cur) {
      if ($curTarget -eq $src) { continue }
      if ($curTarget -and -not (Test-Path -LiteralPath $curTarget)) {
        Remove-Item -LiteralPath $dst -Force
      } elseif ($Adopt -and -not $curTarget -and -not $cur.PSIsContainer) {
        Move-Item -LiteralPath $dst -Destination $src -Force
        Write-Host "adopt $dst"
      } else {
        Write-Warning "exists, left untouched: $dst"
        $conflicts++
        continue
      }
    }

    New-Item -ItemType Directory -Force (Split-Path $dst -Parent) | Out-Null
    New-Link $dst $src
    Write-Host "link $dst"
  }
}

if ($Adopt) { Write-Host 'adopt: review with git diff before committing' }
if ($conflicts) { Write-Warning "$conflicts file(s) skipped; move them aside or use -Adopt"; exit 1 }
exit 0
