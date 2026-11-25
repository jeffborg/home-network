#!/usr/bin/env bash
# check-flux-substitution.sh — fail if a manifest Flux renders contains a ${VAR}
# that postBuild substitution cannot resolve.
#
# The core and apps Kustomizations substitute in strict mode, so one unknown
# variable anywhere in their output (a Grafana `${__url_time_range}`, a shell
# `${1}` in an embedded script) fails the whole build, and apps waits on core.
# `kubectl kustomize` alone does not catch it.
#
# Fix a hit by escaping it as $${VAR} (rendered back to a literal ${VAR}) or by
# using the unbraced $VAR form, which Flux leaves alone. A genuinely new cluster
# variable belongs in the list below.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

# Keys of cluster-settings and cluster-secrets, which exist only in the cluster.
known=(
  AWS_REGION BASE_DOMAIN DKIM_KEY_NAME EXTERNAL_DOMAIN METALLB_LB_RANGE
  SMTP_HOST SMTP_PASS SMTP_USER
  VELERO_BACKUP_B2_REGION VELERO_BACKUP_B2_URL VELERO_BACKUP_BUCKET
  VELERO_BACKUP_BUCKET_B2 VELERO_SECRET_NAME VELERO_SECRET_NAME_B2
)
# Plus the keys of cluster-config-settings and cluster-config-secrets in git.
mapfile -t -O "${#known[@]}" known < <(yq -r '(.data // .stringData // {}) | keys | .[]' cluster/config/*.yaml)

status=0
for dir in cluster/core cluster/apps; do
  while read -r expr; do
    name=$(sed -E 's/^\$\{([A-Za-z_][A-Za-z0-9_]*).*/\1/' <<<"$expr")
    # ${VAR:=default} and ${VAR:-default} resolve even when VAR is unset.
    [[ "$expr" =~ ^\$\{[A-Za-z_][A-Za-z0-9_]*:?[-=] ]] && continue
    [[ " ${known[*]} " == *" $name "* ]] && continue
    files=$(git grep -lF "$expr" -- "$dir" | tr '\n' ' ')
    echo "::error::$dir renders unknown Flux variable $expr (in: ${files:-?})"
    status=1
  done < <(kubectl kustomize "$dir" | grep -oP '(?<!\$)\$\{[^}]*\}' | sort -u)
done

[ "$status" -eq 0 ] && echo "No unknown Flux substitution variables."
exit "$status"
