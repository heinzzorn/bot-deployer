#!/usr/bin/env bash
set -euo pipefail

# Run via sudo by combot's /update handler. combot's process lives inside
# combot.service's cgroup, and update.sh restarts that very service -- so the
# actual update must run as its own transient unit (systemd-run), detached
# from combot's cgroup, or it would kill itself mid-restart.

DEPLOYER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_AS="${SUDO_USER:?trigger-update.sh must be run via sudo}"
TARGET="${1:-all}"

exec /usr/bin/systemd-run --unit=bot-deployer-update --collect --uid="$RUN_AS" "$DEPLOYER_DIR/deploy/update.sh" "$TARGET"
