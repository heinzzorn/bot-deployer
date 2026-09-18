#!/usr/bin/env bash
set -euo pipefail

DEPLOYER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPS_DIR="$(dirname "$DEPLOYER_DIR")"
BOT_DIR="$APPS_DIR/212-bot"
COMBOT_DIR="$APPS_DIR/combot"
SERVICE_USER="$(whoami)"

if [ ! -d "$BOT_DIR" ]; then
    git clone git@github.com-212bot:heinzzorn/212-bot.git "$BOT_DIR"
fi

if [ ! -d "$COMBOT_DIR" ]; then
    git clone git@github.com-combot:heinzzorn/combot.git "$COMBOT_DIR"
fi

"$COMBOT_DIR/deploy/install.sh"

chmod +x "$DEPLOYER_DIR/deploy/update.sh"

sed -e "s#__DEPLOYER_DIR__#$DEPLOYER_DIR#g" -e "s#__USER__#$SERVICE_USER#g" \
    "$DEPLOYER_DIR/deploy/bot-deployer-update.service" | sudo tee /etc/systemd/system/bot-deployer-update.service >/dev/null

sudo cp "$DEPLOYER_DIR/deploy/bot-deployer-update.timer" /etc/systemd/system/bot-deployer-update.timer

echo "$SERVICE_USER ALL=(root) NOPASSWD: /usr/bin/systemctl restart combot.service" \
    | sudo tee /etc/sudoers.d/bot-deployer-update >/dev/null
sudo chmod 440 /etc/sudoers.d/bot-deployer-update

sudo systemctl daemon-reload

echo "Installed. combot.service should be running (started by combot/deploy/install.sh)."
echo "Auto-deploy (bot-deployer-update.timer) is installed but NOT enabled."
echo "Enable it with: sudo systemctl enable --now bot-deployer-update.timer"
