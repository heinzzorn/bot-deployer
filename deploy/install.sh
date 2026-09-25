#!/usr/bin/env bash
set -euo pipefail

# Bootstraps or re-provisions this Pi. Run as root. Every step here is
# idempotent, so this is also what you re-run after a fresh Pi image, or
# after pulling in a change to this script itself.
#
# Must be run from its final location, /var/lib/bot-deployer/apps/bot-deployer
# -- see README.md's "First-time setup" for the one-time bootstrap sequence
# that gets it there (it can't simply be run from an arbitrary clone,
# because it hands ownership of everything it installs to a `bot-deployer`
# system user that has to exist first).
#
# 212-bot is NOT provisioned here. It keeps running exactly as it does
# today (its own user/service, wherever you already have it checked out) --
# only combot and bot-deployer move to the new dedicated-user model in this
# pass. Point BOT212_DIR at it (see .env.example) if it isn't a sibling of
# this checkout.

if [ "$EUID" -ne 0 ]; then
    echo "Run as root (sudo)." >&2
    exit 1
fi

# Files pushed via the GitHub API land as mode 644 (no execute bit) -- a
# plain `git clone` doesn't set one that was never there. This script needs
# to have been made executable by hand once (see README), but everything it
# goes on to invoke below gets fixed here, every run, before it's needed.
chmod +x "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"/*.sh

APPS_DIR="/var/lib/bot-deployer/apps"
DEPLOYER_DIR="$APPS_DIR/bot-deployer"
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ "$SELF_DIR" != "$DEPLOYER_DIR" ]; then
    echo "This must be run from $DEPLOYER_DIR, not $SELF_DIR -- see README.md's bootstrap steps." >&2
    exit 1
fi

"$DEPLOYER_DIR/deploy/provision-users.sh"

mkdir -p "$APPS_DIR"
chown bot-deployer:bot-deployer "$APPS_DIR"
chmod 750 "$APPS_DIR"
chown -R bot-deployer:bot-deployer "$DEPLOYER_DIR"

COMBOT_DIR="$APPS_DIR/combot"
if [ ! -d "$COMBOT_DIR" ]; then
    sudo -u bot-deployer -H git clone git@github.com-combot:heinzzorn/combot.git "$COMBOT_DIR"
else
    echo "$COMBOT_DIR already present, not re-cloning"
fi
chown -R bot-deployer:bot-deployer "$COMBOT_DIR"

sudo -u bot-deployer -H python3 -m venv "$COMBOT_DIR/venv"
sudo -u bot-deployer -H "$COMBOT_DIR/venv/bin/pip" install --upgrade pip
sudo -u bot-deployer -H "$COMBOT_DIR/venv/bin/pip" install -r "$COMBOT_DIR/requirements.txt"

"$DEPLOYER_DIR/deploy/provision-services.sh"

cat <<EOF

Next steps:
  1. Fill in secrets:
       sudo vim /etc/combot/combot.env        # TELEGRAM_BOT_TOKEN=..., TELEGRAM_CHAT_ID=...
       sudo vim /etc/bot-deployer/bot-deployer.env   # same two values (bot-deployer's own copy)
     If 212-bot isn't checked out at $APPS_DIR/212-bot, also add to both files:
       BOT212_DIR=/path/to/your/212-bot/checkout
  2. sudo systemctl start combot.service
  3. Optional: let a local Claude agent SSH in with restricted, no-sudo access:
       sudo ./deploy/provision-claude-ops.sh "ssh-ed25519 AAAA... claude-ops"

EOF
