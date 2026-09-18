#!/usr/bin/env bash
set -euo pipefail

DEPLOYER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPS_DIR="$(dirname "$DEPLOYER_DIR")"
BOT_DIR="$APPS_DIR/212-bot"
COMBOT_DIR="$APPS_DIR/combot"

TARGET="${1:-all}"
BRANCH="${2:-main}"

notify_fail() {
    "$COMBOT_DIR/venv/bin/python3" "$COMBOT_DIR/notify.py" "deploy $TARGET@$BRANCH: $1"
    exit 1
}

# bot-deployer itself always tracks main, regardless of the requested branch.
cd "$DEPLOYER_DIR"
git fetch origin main
if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]; then
    echo "bot-deployer changed, updating self and re-executing"
    git reset --hard origin/main
    exec "$DEPLOYER_DIR/deploy/update.sh" "$TARGET" "$BRANCH"
fi

declare -A REPOS=(["212-bot"]="$BOT_DIR" ["combot"]="$COMBOT_DIR")

case "$TARGET" in
    all) targets=(212-bot combot) ;;
    212-bot|combot) targets=("$TARGET") ;;
    *)
        echo "Unknown deploy target: $TARGET (expected 212-bot, combot, or all)" >&2
        exit 1
        ;;
esac

updated=0
for name in "${targets[@]}"; do
    repo="${REPOS[$name]}"
    cd "$repo"
    if ! git ls-remote --exit-code --heads origin "$BRANCH" >/dev/null; then
        notify_fail "branch '$BRANCH' not found in $name"
    fi
    git fetch origin "$BRANCH"
    if [ "$(git rev-parse HEAD)" != "$(git rev-parse "origin/$BRANCH")" ]; then
        echo "Updating $repo to $BRANCH"
        git reset --hard "origin/$BRANCH"
        updated=1
    fi
done

if [ "$updated" = "1" ]; then
    cd "$COMBOT_DIR"
    ./venv/bin/pip install -r requirements.txt
    sudo /usr/bin/systemctl restart combot.service

    if [ -d "$BOT_DIR/venv" ]; then
        "$BOT_DIR/venv/bin/pip" install -r "$BOT_DIR/requirements.txt"
    fi
    if systemctl is-active --quiet 212-bot.service; then
        sudo /usr/bin/systemctl restart 212-bot.service
    fi

    status="updated"
else
    status="no changes"
fi

"$COMBOT_DIR/venv/bin/python3" "$COMBOT_DIR/notify.py" \
    "deploy $TARGET@$BRANCH: $status (combot=$(git -C "$COMBOT_DIR" rev-parse --short HEAD) 212-bot=$(git -C "$BOT_DIR" rev-parse --short HEAD))"
