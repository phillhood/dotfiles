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

Linking needs Developer Mode (Settings > System > For developers) or an elevated shell. Run it from
Windows PowerShell 5.1 on a bare machine; pwsh 7 isn't required until the profile loads.

## Packages

`install.ps1` keeps its own list, since it can't read the Makefile's:

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

## Known gaps

- **git over SSH.** `core.sshCommand = ssh ...` resolves to Git for Windows' bundled ssh, which can't
  reach the Windows `ssh-agent` service. Keys still work through `-i`, but a passphrase prompts on
  every push.
- **Claude hooks.** Claude Code runs the hooks and statusline through Git Bash, so they need Git for
  Windows and `jq`. The `PreToolUse` hooks match `Bash` only and won't fire for the PowerShell tool.
- **Terminal.** No Windows terminal config is tracked yet; Ghostty's settings would need porting to
  Windows Terminal or WezTerm.
