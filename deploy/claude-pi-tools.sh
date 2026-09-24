#!/usr/bin/env bash
set -euo pipefail

# Forced command for claude-ops (see provision-claude-ops.sh). sshd runs
# this instead of a shell, with the client's requested command in
# $SSH_ORIGINAL_COMMAND -- everything not explicitly matched below is
# refused, on purpose. Start narrow; widen deliberately later, not by
# default.

ALLOWED_UNITS=("combot.service" "bot-deployer-update.service" "212-bot.service")

is_allowed_unit() {
    local unit="$1" u
    for u in "${ALLOWED_UNITS[@]}"; do
        [ "$unit" = "$u" ] && return 0
    done
    return 1
}

usage() {
    echo "Allowed commands: status | logs <unit> [n]" >&2
    echo "Allowed units: ${ALLOWED_UNITS[*]}" >&2
    exit 1
}

# shellcheck disable=SC2206 # deliberate word-splitting of the ssh command
args=(${SSH_ORIGINAL_COMMAND:-})
cmd="${args[0]:-}"

case "$cmd" in
    status)
        systemctl status --no-pager "${ALLOWED_UNITS[@]}"
        ;;
    logs)
        unit="${args[1]:-}"
        n="${args[2]:-50}"
        is_allowed_unit "$unit" || usage
        [[ "$n" =~ ^[0-9]+$ ]] || usage
        [ "$n" -gt 500 ] && n=500
        journalctl -u "$unit" -n "$n" --no-pager
        ;;
    *)
        usage
        ;;
esac
