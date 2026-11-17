# Windows

Windows has no `make` or `stow`, so `install.ps1` does the same job: each package mirrors `$HOME`, only
files are linked, and directories are created as real directories (`--no-folding`). A leading
`Documents\` in a package maps to the real Documents folder, which is how `pwsh-windows` reaches
`Documents\PowerShell\profile.ps1`.

```powershell
git clone https://git.lab.phillhood.ca/phillhood/dotfiles.git $HOME\Dev\phillhood\dotfiles
cd $HOME\Dev\phillhood\dotfiles
.\install.ps1            # link every Windows package
.\install.ps1 -Unlink    # remove the links
.\install.ps1 -Adopt     # one-time takeover of existing real files; review git diff after
```

`git.lab.phillhood.ca` only resolves on the home LAN. Off it, clone the read-only GitHub mirror,
`https://github.com/phillhood/dotfiles.git`, instead.

Linking needs Developer Mode (Settings > System > For developers) or an elevated shell. Run it from
Windows PowerShell 5.1 on a bare machine; pwsh 7 isn't required until the profile loads.

`install.ps1` also locks down `~/.ssh` when it installs the `ssh` package. Created plainly, the folder
inherits the profile folder's permissions, and where another account can read the profile, Windows
OpenSSH refuses `~/.ssh/config` with `Bad owner or permissions`. So it removes inheritance and grants
full control only to the current user, SYSTEM and Administrators
(`icacls /inheritance:r /grant:r ...:(OI)(CI)F`), by SID so it works on non-English Windows. Files
inside inherit that and lose any other account's inherited access, including files from before the
change. Explicit grants set directly on a file inside are left alone.

## Packages

`install.ps1` links the packages tagged `windows` in `packages.conf` (`.\install.ps1 -List` prints
them):

| | |
| --- | --- |
| **Shared** | `starship` `git` `ssh` `claude` `pi` `bat` `k9s` `helm` `nvim` |
| **Windows** | `pwsh-windows` |

Skipped: `zsh`, `tmux`, `herdr`, `htop`, `cava` and `ssh-linux` have no Windows use (they live in WSL);
`ghostty` has no Windows build; `btop` on Windows is btop4win with a different config; `fastfetch`'s
`command` modules are POSIX `sh`.

## XDG_CONFIG_HOME

`install.ps1` sets the user variable `XDG_CONFIG_HOME=%USERPROFILE%\.config` when it's unset. Neovim,
bat, k9s and helm all honour it on Windows, so their packages link to the same `~/.config/...` paths as
on Linux instead of needing Windows-only copies under `AppData`. Starship reads
`~/.config/starship.toml` regardless.

## Shell

`pwsh-windows` is the PowerShell 7 port of `zsh/.zshrc`: same prompt (starship, with the blank line
between prompts and the bar cursor), the same aliases as functions (`ls`/`ll`/`la` via eza, `cat` via
bat, `grep` via rg, `py`/`pip` via uv, `k`/`kctx`/`kns`), and the same integrations (fnm, uv
completions, fzf, atuin, direnv, zoxide as `cd`). Each is skipped when the tool is missing.
PSReadLine stands in for the zsh plugins: Emacs keys, inline history suggestions (Ctrl+f or End to
accept), Ctrl+p/Ctrl+n prefix history search, and a leading space keeps a line out of history. With the
PSFzf module, Tab opens fzf completion as fzf-tab does.

`~/.config/powershell/utils/*.ps1` mirrors `~/.config/utils`: `ask`, `emocode`, `shellbench`,
`dockstats`, `docklogs` and `kdeploy`.

The profile is `profile.ps1` (all hosts), so it also loads in the VS Code terminal.

## Software

`install.ps1` installs nothing. The profile and packages expect:

```powershell
winget install Microsoft.PowerShell Git.Git Starship.Starship eza-community.eza sharkdp.bat `
  BurntSushi.ripgrep.MSVC sharkdp.fd junegunn.fzf ajeetdsouza.zoxide Neovim.Neovim astral-sh.uv `
  Schniz.fnm direnv.direnv GitHub.cli jqlang.jq Helm.Helm Derailed.k9s
Install-Module PSFzf -Scope CurrentUser
```

plus atuin and a Nerd Font (MesloLGS, as Ghostty uses) set in the terminal.

## Line endings

`.gitattributes` forces LF on every checkout. Without it Git for Windows' default `core.autocrlf=true`
writes the Claude hooks and statusline with CRLF, and bash fails on them with `$'\r': command not found`.

## Claude Code

The `claude` package is shared as-is. Claude Code runs its hooks and statusline through Git Bash, so
they need Git for Windows and `jq`. Windows `jq` writes CRLF, so the hooks and statusline strip `\r`
from its output. The `PreToolUse` hooks match `Bash|PowerShell`, and both parse the PowerShell forms
Claude writes: `@'...'@` here-string commit messages, backtick line continuations, the `&` call
operator and `python.exe`.

Merge the canonical settings into `~/.claude/settings.json` rather than copying them, keeping the
live `permissions.allow` entries (`*` replaces arrays):

```powershell
jq -s '.[0] as $l | .[1] as $c | ($l * $c) | .permissions.allow = ((($l.permissions.allow // []) + ($c.permissions.allow // [])) | unique)' `
  $HOME\.claude\settings.json tools\canonical\.claude\settings.json
```

## git over SSH

Git for Windows runs `core.sshCommand` through its own `sh`, where a bare `ssh` is its bundled
`/usr/bin/ssh`. That ssh can't reach the Windows `ssh-agent` service, so every push would prompt for
the key's passphrase. The `sshCommand` in `.gitconfig`, `.gitconfig-shy` and `.gitconfig-aethon`
therefore names the program as `${DOTFILES_SSH:-ssh}`, keeping each identity's own `-i` key.
`install.ps1` sets the user variable `DOTFILES_SSH=C:/Windows/System32/OpenSSH/ssh.exe` when it's
unset and the OpenSSH client is installed. On Linux, WSL and macOS the variable is unset and git runs
plain `ssh` as before.

`.gitconfig` also sets `ssh.variant = ssh`. Without it git can't tell from `${DOTFILES_SSH:-ssh}`
which ssh it's running and probes with an extra `ssh -G` on every connection.

`install.ps1` won't overwrite a `DOTFILES_SSH` that's already set. `tests/test_git_ssh.py` checks
each identity's key and program, with the variable set and unset.

One-time, per machine, after running `install.ps1` and opening a new shell:

```powershell
ssh-add $HOME\.ssh\id_phill        # and id_shy, id_rsa_aethon where those identities are used
```

A key in the older PEM format also needs its `.pub` beside it, or ssh asks for the passphrase
instead of using the agent's copy.

## Terminal

Windows Terminal stands in for Ghostty: Catppuccin Mocha, MesloLGS Nerd Font, bar cursor, 4px padding,
`ctrl+w` closes the pane, and PowerShell 7 is the default profile. WT rewrites its `settings.json`
whenever a setting changes in its UI, so it's a canonical copy in
`tools/canonical/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/`, not a
link. Copy it over on a new machine, after pwsh is installed:

```powershell
Copy-Item tools\canonical\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json `
  $env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json
```

When you change a setting in the WT UI that should follow you, copy it back into the canonical file.
