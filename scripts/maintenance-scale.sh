#!/usr/bin/env bash
# maintenance-scale.sh — scale the heavy app bundle down/up during Longhorn or
# cluster maintenance. Scale DOWN to relieve node/disk I/O while volumes rebuild;
# scale UP to restore once everything is healthy again.
#
#   ./scripts/maintenance-scale.sh down     # scale bundle to 0 (records prior replicas)
#   ./scripts/maintenance-scale.sh up        # restore (to recorded replicas, default 1)
#   ./scripts/maintenance-scale.sh status    # show spec/ready replicas of the bundle
#
# Flux note: these are HelmRelease-managed, but helm-controller only resets
# replicas on an actual chart/values upgrade, not on a periodic reconcile — so a
# manual scale holds through a maintenance window. If you bump one of these
# charts meanwhile it will pop back up; re-run `down` or suspend that HelmRelease.
#
# Uses the current kubectl context by default; override with LH_CONTEXT.
set -euo pipefail
ACTION=${1:-}
CTX_ARG=(); [ -n "${LH_CONTEXT:-}" ] && CTX_ARG=(--context "$LH_CONTEXT")
k(){ kubectl "${CTX_ARG[@]}" "$@"; }
ANN="maintenance-prior-replicas"

# namespace/deployment
BUNDLE=(
  home-automation/emhass
  home-automation/esphome
  home-automation/home-assistant-mcp
  home-automation/home-assistant-dad-mcp
  home-automation/signtools
  media/flaresolverr
  media/jackett
  media/jellyfin
  media/lidarr
  media/ombi
  media/prowlarr
  media/radarr
  media/sabnzbd
  media/seerr
  media/sonarr
  media/tvheadend
  network/uisp
  web-util/hajimari
)

case "$ACTION" in
  down)
    for e in "${BUNDLE[@]}"; do ns=${e%%/*}; d=${e#*/}
      cur=$(k -n "$ns" get deploy "$d" -o jsonpath='{.spec.replicas}' 2>/dev/null || true)
      if [ -n "${cur:-}" ] && [ "$cur" != 0 ]; then
        k -n "$ns" annotate deploy "$d" "$ANN=$cur" --overwrite >/dev/null
      fi
      k -n "$ns" scale deploy "$d" --replicas=0
    done ;;
  up)
    for e in "${BUNDLE[@]}"; do ns=${e%%/*}; d=${e#*/}
      want=$(k -n "$ns" get deploy "$d" -o jsonpath="{.metadata.annotations['$ANN']}" 2>/dev/null || true)
      { [ -z "${want:-}" ] || [ "$want" = 0 ]; } && want=1
      k -n "$ns" scale deploy "$d" --replicas="$want"
    done ;;
  status)
    printf '%-40s %s\n' "DEPLOYMENT" "SPEC/READY"
    for e in "${BUNDLE[@]}"; do ns=${e%%/*}; d=${e#*/}
      printf '%-40s %s\n' "$e" "$(k -n "$ns" get deploy "$d" -o jsonpath='{.spec.replicas}/{.status.readyReplicas}' 2>/dev/null || echo 'missing')"
    done ;;
  *)
    echo "usage: $(basename "$0") down|up|status" >&2; exit 1 ;;
esac
