#!/usr/bin/env bash
set -euo pipefail

DEPLOYER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPS_DIR="$(dirname "$DEPLOYER_DIR")"
BOT_DIR="$APPS_DIR/212-bot"
COMBOT_DIR="$APPS_DIR/combot"

cd "$DEPLOYER_DIR"
git fetch origin main
if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]; then
    echo "bot-deployer changed, updating self and re-executing"
    git reset --hard origin/main
    exec "$DEPLOYER_DIR/deploy/update.sh"
fi

updated=0
for repo in "$BOT_DIR" "$COMBOT_DIR"; do
    cd "$repo"
    git fetch origin main
    if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]; then
        echo "Updating $repo"
        git reset --hard origin/main
        updated=1
    fi
done

if [ "$updated" = "1" ]; then
    cd "$COMBOT_DIR"
    ./venv/bin/pip install -r requirements.txt
    sudo /usr/bin/systemctl restart combot.service
    ./venv/bin/python3 notify.py "combot updated to $(git -C "$COMBOT_DIR" rev-parse --short HEAD), bot logic at $(git -C "$BOT_DIR" rev-parse --short HEAD)"
fi
