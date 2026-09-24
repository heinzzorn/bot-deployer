# bot-deployer

Deploy automation for [212-bot](https://github.com/heinzzorn/212-bot) (its
own standalone service) and [combot](https://github.com/heinzzorn/combot)
(Telegram communicator). Updates one or both repos and restarts the affected
service(s) if anything changed, triggered on demand by combot (send it
`/deploy`, `/deploy 212-bot`, `/deploy combot`, or `/deploy combot my-branch`)
— not on a timer.

## User model

Three separate system users, least-privilege:

- **`bot-deployer`** — owns the checkouts under `/var/lib/bot-deployer/apps/`
  and the GitHub deploy keys in `/var/lib/bot-deployer/.ssh/`. It's the only
  identity that ever writes to those directories or performs a
  `git reset --hard`. It's also the only identity that can restart
  `combot.service` and `212-bot.service` (via a narrow sudoers grant) — it
  does that itself, from inside `update.sh`, after actually changing
  something.
- **`combot`** — read-only (group) access to the checkouts, so it can start
  itself and read its own sibling `212-bot` checkout, but can't modify
  either. Its only sudo rights are: start/stop `212-bot.service`, read its
  own journal, reboot, and run `deploy/trigger-update.sh` — never the deploy
  script itself. That script always executes as `bot-deployer`, regardless
  of who's allowed to trigger it (see `trigger-update.sh`), so triggering a
  deploy and performing one are deliberately different identities.
- **`claude-ops`** (optional) — for a local Claude Code agent's SSH access to
  this Pi, kept entirely separate from your own admin login. No home
  directory, no sudo entry at all, and its SSH key can only invoke one
  whitelisted read-only script (`claude-pi-tools`: service status, journal
  tail) — enforced by sshd itself before any shell runs. See
  `provision-claude-ops.sh`.

212-bot is not part of this user model yet — it still runs under whatever
user set it up (per its own README), wherever it's checked out. That
migration is a deliberate follow-up, not part of this pass; both combot and
bot-deployer look it up via an optional `BOT212_DIR` env var (see
`.env.example` in each), defaulting to a sibling checkout if unset.

## Secrets

Never in git, never inside a repo checkout. Each service that needs the
Telegram bot token gets its own copy, each in its own root-owned,
`600`-permission file, readable only by that service's user:

```
/etc/combot/combot.env             # combot.service's EnvironmentFile
/etc/bot-deployer/bot-deployer.env # sourced by update.sh, for its own notify.py calls
```

Both are created empty by `provision-services.sh` — fill them in by hand
after provisioning (`sudo vim /etc/combot/combot.env`, etc.), never commit
real values, and re-run `provision-services.sh` any time without fear of it
overwriting a file that already has content.

## Layout

```
/var/lib/bot-deployer/            # bot-deployer's home
  .ssh/                            # deploy keys, one per repo, see below
  apps/
    bot-deployer/                  # this repo
    combot/
    212-bot/                       # optional here -- see BOT212_DIR above
```

Each repo has its own read-only GitHub deploy key, so
`/var/lib/bot-deployer/.ssh/config` needs a distinct host alias per repo:

```
Host github.com-212bot
    HostName github.com
    IdentityFile /var/lib/bot-deployer/.ssh/id_ed25519_212bot
    IdentitiesOnly yes

Host github.com-combot
    HostName github.com
    IdentityFile /var/lib/bot-deployer/.ssh/id_ed25519_combot
    IdentitiesOnly yes

Host github.com-bot-deployer
    HostName github.com
    IdentityFile /var/lib/bot-deployer/.ssh/id_ed25519_bot_deployer
    IdentitiesOnly yes
```

Generate fresh deploy keys for a fresh Pi rather than reusing old ones.

## First-time setup (fresh Pi)

Everything except secret values and the SSH deploy keys themselves is
scripted and idempotent. As your own admin user (with real sudo):

```
# 1. The bot-deployer user has to exist before anything can be cloned as it
#    (chicken-and-egg), so bootstrap from a throwaway clone first:
git clone git@github.com-bot-deployer:heinzzorn/bot-deployer.git /tmp/bot-deployer-bootstrap
sudo /tmp/bot-deployer-bootstrap/deploy/provision-users.sh

# 2. Now the bot-deployer user (and its home) exist -- put its SSH config
#    and keys in place (see Layout above), then clone the real checkout as it:
sudo -u bot-deployer -H git clone git@github.com-bot-deployer:heinzzorn/bot-deployer.git \
    /var/lib/bot-deployer/apps/bot-deployer
rm -rf /tmp/bot-deployer-bootstrap

# 3. Run the real installer from its final location.
sudo /var/lib/bot-deployer/apps/bot-deployer/deploy/install.sh
```

`install.sh` clones `combot` alongside itself, creates its venv, and
installs the systemd unit + sudoers rules for both. It prints the exact
next steps (fill in the two `.env` files, start `combot.service`, optionally
provision `claude-ops`) when it finishes.

212-bot's own setup is unchanged and separate — see its README.

## Deploys

Deploys happen when you send `/deploy [212-bot|combot] [branch]` to the bot
on Telegram (omit the target to check both, omit the branch for `main`):
combot's handler runs `sudo deploy/trigger-update.sh <target> <branch>`,
which launches `deploy/update.sh <target> <branch>` as `bot-deployer`, as its
own transient systemd unit (`systemd-run`), detached from combot's cgroup.
That detachment matters because `update.sh` restarts `combot.service` itself
— if it ran inside combot's own cgroup, that restart would kill it
mid-update. `bot-deployer` always fetches/resets *itself* from `main` first,
regardless of the requested branch (only `212-bot`/`combot` can be deployed
from a branch), then fetches/resets whichever of `212-bot`/`combot` was
targeted from that branch. If a requested branch doesn't exist on a targeted
repo, it notifies you and stops rather than failing silently. If anything
changed: reinstalls dependencies, restarts `combot.service` unconditionally
(it imports 212-bot's code directly), and restarts `212-bot.service` too but
only if it was already running (a deliberate `/bot stop` is respected, not
undone by a deploy). Always sends a Telegram notification with the result.

You can also run this directly on the Pi for a manual check outside of
Telegram:

```
sudo -u bot-deployer /var/lib/bot-deployer/apps/bot-deployer/deploy/update.sh [212-bot|combot] [branch]
```

## claude-ops (restricted access for a local Claude Code agent)

If you run Claude Code locally and want it able to SSH into this Pi to
check on things, give it its own key and account rather than sharing yours:

```
sudo ./deploy/provision-claude-ops.sh "ssh-ed25519 AAAA... claude-ops"
```

This creates `claude-ops` with no home, no password login, and no sudo
entry at all, and restricts its SSH key (via `authorized_keys` flags and a
forced `command=`) to only ever run `/usr/local/bin/claude-pi-tools` — a
small whitelist of read-only operations (`status`, `logs <unit> [n]`). Point
your local agent's SSH config at this key/user, never your own. The script
prints an `sshd_config` line to add by hand if it isn't already there
(deliberately not edited automatically, since a mistake there can lock out
SSH entirely).

## Recovery

If a bad commit breaks something, SSH in and fix it directly — this bypasses
the deploy automation entirely:

```
sudo -u bot-deployer git -C /var/lib/bot-deployer/apps/212-bot reset --hard <known-good-commit>   # or combot
sudo systemctl restart combot.service
```
