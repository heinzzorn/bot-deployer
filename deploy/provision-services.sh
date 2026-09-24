#!/usr/bin/env bash
set -euo pipefail

# Idempotent: /etc/<service> secret directories, the combot systemd unit,
# and sudoers rules for combot and bot-deployer. Run after provision-users.sh
# and after combot/bot-deployer have been cloned into APPS_DIR (install.sh
# does both, in order). Safe to re-run -- it never overwrites an existing
# .env file, and validates every sudoers fragment before installing it.

if [ "$EUID" -ne 0 ]; then
    echo "Run as root (sudo)." >&2
    exit 1
fi

APPS_DIR="/var/lib/bot-deployer/apps"
COMBOT_DIR="$APPS_DIR/combot"
DEPLOYER_DIR="$APPS_DIR/bot-deployer"

install_env_dir() {
    local name="$1" owner="$2"
    local dir="/etc/$name" env_file="/etc/$name/$name.env"
    mkdir -p "$dir"
    chown "$owner:$owner" "$dir"
    chmod 700 "$dir"
    if [ ! -f "$env_file" ]; then
        touch "$env_file"
        echo "Created empty $env_file -- fill in its secrets before starting $name"
    fi
    chown "$owner:$owner" "$env_file"
    chmod 600 "$env_file"
}

install_env_dir combot combot
install_env_dir bot-deployer bot-deployer

# --- combot.service ---
sed -e "s#__REPO_DIR__#$COMBOT_DIR#g" -e "s#__USER__#combot#g" \
    "$COMBOT_DIR/deploy/combot.service" | tee /etc/systemd/system/combot.service >/dev/null

# --- sudoers: combot ---
# combot only ever triggers deploys and controls 212-bot / itself via
# systemctl -- it never gets a blanket grant, and never runs the deploy
# script itself (bot-deployer's own user does that, see trigger-update.sh).
SUDOERS_COMBOT="$(mktemp)"
cat > "$SUDOERS_COMBOT" <<EOF
combot ALL=(root) NOPASSWD: /usr/bin/systemctl start 212-bot.service
combot ALL=(root) NOPASSWD: /usr/bin/systemctl stop 212-bot.service
combot ALL=(root) NOPASSWD: /usr/bin/journalctl -u combot.service *
combot ALL=(root) NOPASSWD: /usr/bin/systemctl reboot
combot ALL=(root) NOPASSWD: $DEPLOYER_DIR/deploy/trigger-update.sh *
EOF
visudo -cf "$SUDOERS_COMBOT"
install -m 440 -o root -g root "$SUDOERS_COMBOT" /etc/sudoers.d/combot
rm -f "$SUDOERS_COMBOT"

# --- sudoers: bot-deployer ---
# bot-deployer's own update.sh (launched detached, as this user, by
# trigger-update.sh) is the only thing allowed to restart the services it
# just updated.
SUDOERS_DEPLOYER="$(mktemp)"
cat > "$SUDOERS_DEPLOYER" <<EOF
bot-deployer ALL=(root) NOPASSWD: /usr/bin/systemctl restart combot.service
bot-deployer ALL=(root) NOPASSWD: /usr/bin/systemctl restart 212-bot.service
EOF
visudo -cf "$SUDOERS_DEPLOYER"
install -m 440 -o root -g root "$SUDOERS_DEPLOYER" /etc/sudoers.d/bot-deployer
rm -f "$SUDOERS_DEPLOYER"

systemctl daemon-reload
systemctl enable combot.service

echo "Services and sudoers installed. combot.service is enabled but not started."
echo "Fill in /etc/combot/combot.env and /etc/bot-deployer/bot-deployer.env, then:"
echo "  sudo systemctl start combot.service"
