# bot-deployer

Deploy automation for [212-bot](https://github.com/heinzzorn/212-bot) (bot
logic) and [combot](https://github.com/heinzzorn/combot) (Telegram
communicator). Updates one or both repos and restarts `combot.service` if
anything changed, triggered on demand by combot (send it `/deploy`,
`/deploy 212-bot`, or `/deploy combot`) — not on a timer.

## Layout

This repo, `212-bot`, and `combot` must all be cloned as siblings under the
same parent directory:

```
~/apps/212-bot/
~/apps/combot/
~/apps/bot-deployer/
```

Each repo has its own read-only GitHub deploy key, so `~/.ssh/config` needs a
distinct host alias per repo, e.g.:

```
Host github.com-212bot
    HostName github.com
    IdentityFile ~/.ssh/id_ed25519_github
    IdentitiesOnly yes

Host github.com-combot
    HostName github.com
    IdentityFile ~/.ssh/id_ed25519_combot
    IdentitiesOnly yes

Host github.com-bot-deployer
    HostName github.com
    IdentityFile ~/.ssh/id_ed25519_bot_deployer
    IdentitiesOnly yes
```

## First-time setup

Clone this repo (using its own host alias), then:

```
cd bot-deployer
./deploy/install.sh
```

This clones `212-bot` and `combot` if missing, runs combot's own install
(venv + `combot.service`), and installs a sudoers rule letting combot trigger
`deploy/trigger-update.sh` (and restart `combot.service`) without a password.

Deploys happen when you send `/deploy [212-bot|combot]` to the bot on
Telegram (omit the target to check both): combot's handler runs
`sudo deploy/trigger-update.sh <target>`, which launches `deploy/update.sh
<target>` as its own transient systemd unit (`systemd-run`), detached from
combot's cgroup. That detachment matters because `update.sh` restarts
`combot.service` itself — if it ran inside combot's own cgroup, that restart
would kill it mid-update. `update.sh` always fetches/resets `bot-deployer`
(itself) first, then fetches/resets whichever of `212-bot`/`combot` was
targeted, reinstalls dependencies and restarts `combot.service` if anything
changed, and always sends a Telegram notification with the result.

You can also run `./deploy/update.sh [212-bot|combot]` directly on the Pi for
a manual check outside of Telegram.

## Recovery

If a bad commit breaks something, SSH in and fix it directly — this bypasses
the deploy automation entirely:

```
cd ~/apps/212-bot && git reset --hard <known-good-commit>   # or combot
sudo systemctl restart combot.service
```
