# SSH client configuration

The `ssh` Home Manager feature owns `~/.ssh/config` on both `nerv` and `asuka`.
It holds only defaults that suit every destination. Host entries live in
`~/.ssh/config.local`, which Home Manager never writes and the flake never
names, so which hosts a machine reaches, as whom, through which jump host and
with which key stays on that machine.

## What the managed file sets

On `nerv`, with the 1Password agent, the generated file is:

```sshconfig
Include ~/.ssh/config.local

Host *
  ControlMaster auto
  ControlPath /run/user/%i/ssh-%C
  ControlPersist 10m
  HashKnownHosts yes
  IdentityAgent ~/.1password/agent.sock
  ServerAliveCountMax 3
  ServerAliveInterval 30
  UpdateHostKeys yes
```

On `asuka`, control sockets go to `~/.ssh/control/%C` and `IdentityAgent` names
Bitwarden's `~/.bitwarden-ssh-agent.sock`, because the `darwin` profile
imports `bitwarden-darwin`.

- **Multiplexing.** The first connection to a destination becomes a master,
  and every later `ssh`, `scp` or Git operation to it reuses that connection
  without a new handshake or agent approval. The master stays for ten minutes
  after its last session closes. `ssh -O exit <host>` ends it early, and
  `ssh -O check <host>` says whether one is running.
- **Control sockets.** `%C` is a hash of the local host, destination, port,
  user and jump host, so every destination gets its own socket at a fixed
  length that fits the Unix socket path limit. On Linux they live in logind's
  per-user runtime directory, which is private, mode `0700`, and emptied at
  logout. The path uses `%i`, the local UID, rather than `${XDG_RUNTIME_DIR}`,
  because OpenSSH aborts every connection whose `ControlPath` names an unset
  variable. macOS has no runtime directory and its `$TMPDIR` is too long for
  the limit, so Home Manager activation creates `~/.ssh/control` with mode
  `0700`. Activation also creates `~/.ssh` itself with mode `0700` on a machine
  that has none yet, and leaves an existing one alone.
- **Dead connections.** A peer that stops answering is dropped after about 90
  seconds instead of whenever TCP gives up, which matters more when several
  sessions share one master.
- **Known hosts.** New entries are recorded as hashes, so `known_hosts` does not
  list where this account connects. Existing entries stay readable until
  `ssh-keygen -H` hashes them. Shell completion can no longer read hashed
  entries, so give a host you complete often an entry in `config.local`.
  `UpdateHostKeys` accepts a server's added or rotated host keys once it has
  authenticated with a key already trusted.
- **Agent.** Whichever password manager feature a profile imports sets
  `IdentityAgent` to its own socket, so ssh reaches the agent even in a session
  that never inherited `SSH_AUTH_SOCK`. Those features keep exporting
  `SSH_AUTH_SOCK` as well, because `ssh-keygen` does not read `ssh_config`, and
  Git and Jujutsu sign commits through it. A profile that imported two of them
  would fail to evaluate on the conflicting `IdentityAgent` rather than pick one.

Nothing here forwards the agent, X11 or ports, and nothing weakens host key
checking. OpenSSH's defaults stand for everything not listed.

## How the local file wins

ssh reads `~/.ssh/config` from the top and keeps the first value it obtains
for each option. Home Manager writes the `Include` line above every block, so
the local file is read first. A setting in a matching `Host` block there wins
over the managed `Host *` default for that host, and the managed block only
fills in what the local entry left unset. That includes `IdentityAgent`, so a
host can use another agent. A missing `config.local` is not an error.

```sshconfig
# ~/.ssh/config.local
Host build
  HostName build.example.org
  User builder
  ProxyJump bastion
  ForwardAgent yes
```

Options written in the local file before its first `Host` line apply to every
destination and override the managed defaults as well. `Include` takes `~`
from the account's home directory, not from `$HOME`.

## Moving an existing configuration

Home Manager will not overwrite a hand-written `~/.ssh/config`. On `nerv`, the
first activation that manages the file moves the existing one aside through
`seele-home-backup` to `~/.ssh/config.bak`, and a `config.bak` already there
is kept as a numbered `config.bak.~N~`. On `asuka`, Home Manager moves it to
`~/.ssh/config.bak`, and refuses to activate if that backup already exists.
Either way the old entries stop applying until they are moved.

The direct route is to move them before activating:

```sh
mv ~/.ssh/config ~/.ssh/config.local
```

After an activation has already backed the file up, move the backup instead:

```sh
mv ~/.ssh/config.bak ~/.ssh/config.local
```

Then delete anything in `config.local` that the managed defaults now cover,
such as a `Host *` block for 1Password's or Bitwarden's `IdentityAgent`, or
control-socket settings. Check the effective result for a host with
`ssh -G <host>`.

## Not a portable application

The `ssh` feature publishes no `seele.portable` entry. The portable builder
carries configuration that lives under `~/.config`, while ssh reads only
`~/.ssh/config` or a file passed with `-F`. A borrowed machine's ssh
configuration and known hosts are that machine's state. Wrapping ssh with `-F`
would replace them instead of confining the flake's settings to a directory of
their own.
