#!/usr/bin/env bash
set -euo pipefail

# Idempotent: creates the system users combot and bot-deployer expect.
# Safe to re-run (e.g. after a fresh Pi image, or to pick up a change here).
#
# 212-bot is NOT provisioned by this script -- it still runs under
# whichever user runs its own deploy/install.sh, per its current README.
# That migration is tracked separately; see bot-deployer/README.md.

if [ "$EUID" -ne 0 ]; then
    echo "Run as root (sudo)." >&2
    exit 1
fi

if ! id -u bot-deployer >/dev/null 2>&1; then
    useradd --system --create-home --home-dir /var/lib/bot-deployer \
        --shell /usr/sbin/nologin bot-deployer
    echo "Created user bot-deployer (home: /var/lib/bot-deployer)"
else
    echo "User bot-deployer already exists, skipping"
fi

# useradd's default HOME_MODE is often 700, which blocks ANY group member
# from traversing into it at all -- regardless of a subdirectory's own
# permissions. combot needs to reach /var/lib/bot-deployer/apps/combot as a
# group member (see usermod below), so the home directory itself needs
# group-execute too. Set every run, not just on first creation, so a wrong
# mode (e.g. from before this line existed) self-heals.
chmod 750 /var/lib/bot-deployer

if ! id -u combot >/dev/null 2>&1; then
    useradd --system --no-create-home --shell /usr/sbin/nologin combot
    echo "Created user combot"
else
    echo "User combot already exists, skipping"
fi

# combot only needs to read (not write) the checkouts bot-deployer owns.
usermod -aG bot-deployer combot
