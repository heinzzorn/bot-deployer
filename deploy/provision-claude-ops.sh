#!/usr/bin/env bash
set -euo pipefail

# Provisions a separate, deliberately restricted account for a local Claude
# Code agent's SSH access to this Pi -- distinct from your own admin login
# and from the combot/bot-deployer/212-bot service accounts. It gets:
#   - no home directory, no password login
#   - no sudo entry at all (none installed by this script or any other)
#   - read-only journal access (systemd-journal group) for `logs`
#   - an SSH key that can ONLY run /usr/local/bin/claude-pi-tools (a
#     read-only whitelist: service status, journal tail) -- sshd enforces
#     this itself via a forced command, before any shell runs, so it holds
#     even if the agent is compromised or misdirected.
#
# Usage: sudo ./provision-claude-ops.sh "ssh-ed25519 AAAA... claude-ops"

if [ "$EUID" -ne 0 ]; then
    echo "Run as root (sudo)." >&2
    exit 1
fi

PUBKEY="${1:?Usage: $0 \"<ssh public key for claude-ops>\"}"

if ! id -u claude-ops >/dev/null 2>&1; then
    useradd --system --no-create-home --shell /usr/sbin/nologin claude-ops
    echo "Created user claude-ops"
else
    echo "User claude-ops already exists, skipping"
fi

# Read-only journal access, so `logs` works without needing sudo.
usermod -aG systemd-journal claude-ops

install -D -m 755 -o root -g root \
    "$(dirname "${BASH_SOURCE[0]}")/claude-pi-tools.sh" /usr/local/bin/claude-pi-tools

mkdir -p /etc/ssh/authorized_keys.d
printf 'restrict,no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command="/usr/local/bin/claude-pi-tools" %s\n' \
    "$PUBKEY" > /etc/ssh/authorized_keys.d/claude-ops
chown root:root /etc/ssh/authorized_keys.d/claude-ops
chmod 644 /etc/ssh/authorized_keys.d/claude-ops

echo
echo "claude-ops is provisioned with NO sudo entry."
echo
if grep -qE '^\s*AuthorizedKeysFile\s+.*authorized_keys\.d/%u' /etc/ssh/sshd_config 2>/dev/null; then
    echo "sshd_config already points at /etc/ssh/authorized_keys.d/%u -- nothing else to do."
else
    echo "ACTION NEEDED: add this line to /etc/ssh/sshd_config (not done automatically --"
    echo "editing sshd_config unattended risks locking out SSH):"
    echo
    echo "    AuthorizedKeysFile /etc/ssh/authorized_keys.d/%u"
    echo
    echo "Then: sudo sshd -t && sudo systemctl reload sshd"
fi
