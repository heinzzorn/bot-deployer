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

chmod +x "$DEPLOYER_DIR/deploy/update.sh" "$DEPLOYER_DIR/deploy/trigger-update.sh"

cat <<EOF | sudo tee /etc/sudoers.d/bot-deployer >/dev/null
$SERVICE_USER ALL=(root) NOPASSWD: /usr/bin/systemctl restart combot.service
$SERVICE_USER ALL=(root) NOPASSWD: $DEPLOYER_DIR/deploy/trigger-update.sh
EOF
sudo chmod 440 /etc/sudoers.d/bot-deployer

echo "Installed. combot.service should be running (started by combot/deploy/install.sh)."
echo "Send /update to the bot on Telegram to trigger a deploy check on demand."
