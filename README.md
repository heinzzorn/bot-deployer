# bot-deployer

Deploy automation for [212-bot](https://github.com/heinzzorn/212-bot) (bot
logic) and [combot](https://github.com/heinzzorn/combot) (Telegram
communicator). Clones/updates both repos and restarts `combot.service` when
either changes.

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
(venv + `combot.service`), and installs (but does not enable) a systemd timer
that checks for updates every 5 minutes.

Enable auto-deploy:

```
sudo systemctl enable --now bot-deployer-update.timer
```

Without it, updates only happen when `./deploy/update.sh` is run manually.

## Recovery

If a bad commit breaks something, SSH in and fix it directly — this bypasses
the deploy automation entirely:

```
cd ~/apps/212-bot && git reset --hard <known-good-commit>   # or combot
sudo systemctl restart combot.service
```
