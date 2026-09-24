#!/usr/bin/env bash
set -euo pipefail

# Run via sudo by combot's /deploy handler. combot's process lives inside
# combot.service's cgroup, and update.sh restarts that very service -- so the
# actual update must run as its own transient unit (systemd-run), detached
# from combot's cgroup, or it would kill itself mid-restart.
#
# Always runs as the bot-deployer user, regardless of who's allowed to
# trigger it (sudoers restricts that to combot) -- bot-deployer is the only
# identity that owns the checkouts and holds the deploy keys, so it's the
# only one that can actually perform an update. "Allowed to trigger a
# deploy" and "allowed to perform one" are deliberately different users.

DEPLOYER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-all}"
BRANCH="${2:-main}"

exec /usr/bin/systemd-run --unit=bot-deployer-update --collect --uid=bot-deployer "$DEPLOYER_DIR/deploy/update.sh" "$TARGET" "$BRANCH"
