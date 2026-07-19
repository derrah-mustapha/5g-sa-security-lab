#!/bin/bash
# Convenience wrapper around docker compose.
#
#   scripts/lab.sh up baseline|hardened   start the lab with that profile (recreates it)
#   scripts/lab.sh down                   stop and remove the lab (keeps the subscriber DB)
#   scripts/lab.sh status                 container state + UE registrations
#   scripts/lab.sh rogue                  start the unauthorised gNB (attack demo)
set -euo pipefail
cd "$(dirname "$0")/.."

case "${1:-}" in
  up)
    PROFILE=${2:?baseline|hardened}
    python3 scripts/gen_configs.py >/dev/null
    export PROFILE
    if [ "$PROFILE" = hardened ]; then
      export SLICE_ISOLATION=yes N2_ALLOW=10.10.2.20      # UPF slice isolation + AMF N2 allow-list
    fi
    docker compose --profile rogue down --remove-orphans >/dev/null 2>&1 || true
    docker compose up -d
    echo "waiting for the core to settle..."; sleep 30
    ./scripts/provision.sh >/dev/null
    docker compose restart ue1 ue2 >/dev/null 2>&1
    sleep 12
    "$0" status
    ;;
  down)
    docker compose --profile rogue down --remove-orphans
    ;;
  status)
    docker compose ps --format 'table {{.Name}}\t{{.Status}}'
    for ue in ue1 ue2; do
      printf '%s: ' "$ue"
      docker compose logs "$ue" 2>&1 | grep -oE 'TUN interface\[uesimtun0, [0-9.]+\] is up|Registration reject.*|PDU Session Establishment Reject.*' | tail -1 || true
    done
    ;;
  rogue)
    docker compose --profile rogue up rogue-gnb
    ;;
  *)
    sed -n '2,8p' "$0"; exit 1;;
esac
