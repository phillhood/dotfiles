# SSH

## ~/.ssh/config is not stowed

`~/.ssh/config` stays a real per-machine file. Colima and the AWS Toolkit for VSCode both write host
blocks into it, and if it were a stow symlink those writes would land in this repo. Tracked hosts live in
fragments instead:

- `ssh/.ssh/config.d/forge.conf`: the Forgejo git host, on every machine.
- `ssh-linux/.ssh/config.d/homelab.conf`: homelab hosts, Linux only, because they pin
  `~/.ssh/id_ed25519_homelab` with `IdentitiesOnly yes` and that key is not on the mac.

`~/.ssh/config` pulls them in with

```
Include ~/.ssh/config.d/*.conf
```

which must stay the first line: ssh takes the first value it finds for each keyword, so anything above
the `Include` silently wins over the fragments. A glob that matches nothing is not an error, so the same
skeleton works on a machine with no fragments stowed.

`make ssh-config` (also run by `make install`) installs that skeleton from `tools/canonical/.ssh/config`
at mode 600 when `~/.ssh/config` is absent or a dangling symlink, leaves an existing real file alone,
and warns if the `Include` line is missing.

## Forgejo remote

Clone over HTTPS first, because SSH needs config this repo provides. Forgejo's SSH is its built-in
server on 192.168.1.102 port 2222, not port 22 (that is the host's own sshd, which rejects `git@`), and
the `git.lab.phillhood.ca` reverse proxy only forwards HTTP. Once `forge.conf` is stowed,
`forge.home` and `git.lab.phillhood.ca` both route to :2222, and

```sh
git remote set-url origin git@git.lab.phillhood.ca:phillhood/dotfiles.git
```

works. Port 2222 is LAN-only, so off-LAN needs Tailscale or HTTPS. `IdentityFile` is `~/.ssh/id_phill`,
which resolves on both machines: a real key on Arch, a symlink to `id_ed25519` on the mac.
