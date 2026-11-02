#!/usr/bin/env bash
# longhorn-im-drain.sh — move engine processes out of stale instance-managers
# after a Longhorn version upgrade. Run this after EVERY Longhorn minor bump.
#
# Background: a Longhorn upgrade swaps two different images, and only one of them
# can move while volumes are attached.
#
#   - The ENGINE image is delivered by the engine-image-ei-* DaemonSet and mounted
#     into instance-manager pods, so the engine *binary* live-upgrades in place.
#     Every volume will report the new currentImage within minutes.
#   - The INSTANCE-MANAGER image is the pod that *hosts* the engine and replica
#     processes. A process cannot be moved between pods — it has to stop and
#     start again. So after an upgrade you get two generations per node: the new
#     one holding the replicas (they migrate on their own) and the OLD one still
#     holding every engine process.
#
# That means the data plane looks finished while every engine is still hosted by
# the previous release's instance-manager, each of which keeps reserving
# guaranteed-instance-manager-cpu (12% of node CPU by default) and carries a PDB
# with disruptionsAllowed=0 — so it is also a node-drain blocker.
#
# `kubectl rollout restart` does NOT reliably fix this. With Recreate, if the
# replacement pod lands on the same node before csi-attacher tears down the
# VolumeAttachment, the volume never reaches `detached`, the engine process never
# stops, and it stays where it was. Measured on the 1.7.3 hop: 13 of 18 engines
# were being served by pods that had already been restarted and had not moved.
# It works only as a race.
#
# The volume has to genuinely detach. This script scales each consuming workload
# to 0, WAITS for the volume to report detached, then scales it back — and groups
# by PV, so a volume shared by several workloads has all of them taken down
# together (cycling them one at a time can never detach).
#
#   ./scripts/longhorn-im-drain.sh                    # list what needs draining (read-only)
#   ./scripts/longhorn-im-drain.sh drain              # cycle everything, one volume at a time
#   ./scripts/longhorn-im-drain.sh list  media        # preview just a namespace
#   ./scripts/longhorn-im-drain.sh drain node1        # one node at a time
#   ./scripts/longhorn-im-drain.sh drain sonarr radarr media/lidarr
#
# Any trailing arguments filter the plan. A filter matches on node name, exact
# namespace, workload name, or PVC name, so `media`, `node1`, `sonarr` and
# `media/sonarr` all work. Always `list` with the same filters first — the plan
# it prints is exactly what `drain` will cycle.
#
# Filters select VOLUMES, not individual workloads: if a selected volume is
# shared, every consumer of it is still taken down together, because a partial
# scale-down can never detach.
#
# The target image is read from the live default-instance-manager-image setting,
# so there is nothing to edit per release.
#
# Uses the current kubectl context by default; override with LH_CONTEXT / LH_NS.
set -euo pipefail
NS=${LH_NS:-longhorn-system}; MODE=${1:-list}
shift || true
FILTERS=("$@")
CTX_ARG=(); [ -n "${LH_CONTEXT:-}" ] && CTX_ARG=(--context "$LH_CONTEXT")
k(){ kubectl "${CTX_ARG[@]}" "$@"; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

TARGET=$(k -n "$NS" get settings.longhorn.io default-instance-manager-image -o jsonpath='{.value}')
[ -n "$TARGET" ] || { echo "could not read default-instance-manager-image"; exit 1; }
echo "target instance-manager image: $TARGET"

# --- stability guard: draining churns replicas, so only do it from a clean base ---
k -n "$NS" get nodes.longhorn.io -o json >"$TMP/lhnodes.json"
k -n "$NS" get volumes.longhorn.io -o json >"$TMP/vols.json"
UNHEALTHY=$(python3 - "$TMP/vols.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
print(sum(1 for v in d["items"] if v["status"].get("state")=="attached" and v["status"].get("robustness")!="healthy"))
PY
)
NOTREADY=$(python3 - "$TMP/lhnodes.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
print(" ".join(n["metadata"]["name"] for n in d["items"]
      if next((c["status"] for c in n["status"]["conditions"] if c["type"]=="Ready"),"")!="True"))
PY
)
if [ "$UNHEALTHY" != 0 ] || [ -n "$NOTREADY" ]; then
  echo "⚠️  not a clean base: $UNHEALTHY attached volume(s) not healthy; NotReady node(s):${NOTREADY:- none}"
  echo "    Let rebuilds finish first — draining now stacks a detach on top of a rebuild."
  [ "${FORCE:-0}" = 1 ] || exit 1
fi

# --- map stale-IM engines -> PV -> PVC -> consuming workloads, grouped by PV ---
k -n "$NS" get instancemanagers.longhorn.io -o json >"$TMP/im.json"
k get pv -o json >"$TMP/pv.json"
k get pods -A -o json >"$TMP/pods.json"
k get replicasets -A -o json >"$TMP/rs.json"

python3 - "$TMP" "$TARGET" >"$TMP/plan.txt" <<'PY'
import json,sys,collections
T,target=sys.argv[1],sys.argv[2]
im=json.load(open(f"{T}/im.json"))["items"]
pvs=json.load(open(f"{T}/pv.json"))["items"]
pods=json.load(open(f"{T}/pods.json"))["items"]
rss={(r["metadata"]["namespace"],r["metadata"]["name"]):r for r in json.load(open(f"{T}/rs.json"))["items"]}

stale={}   # pv -> node holding the engine in an old IM
for m in im:
    if m["spec"]["image"]==target: continue
    for eng in (m["status"].get("instanceEngines") or {}):
        stale[eng.rsplit("-e-",1)[0]]=m["spec"]["nodeID"]

pv2claim={p["metadata"]["name"]:(p["spec"].get("claimRef") or {}) for p in pvs}

def owner(pod):
    ors=pod["metadata"].get("ownerReferences") or []
    if not ors: return ("Pod",pod["metadata"]["name"])
    o=ors[0]
    if o["kind"]=="ReplicaSet":
        rs=rss.get((pod["metadata"]["namespace"],o["name"]))
        ro=(rs["metadata"].get("ownerReferences") or [{}])[0] if rs else {}
        return (ro["kind"],ro["name"]) if ro.get("kind") else ("ReplicaSet",o["name"])
    return (o["kind"],o["name"])

claim2wl=collections.defaultdict(set)
for p in pods:
    if p["status"].get("phase")!="Running": continue
    for v in (p["spec"].get("volumes") or []):
        c=(v.get("persistentVolumeClaim") or {}).get("claimName")
        if c: claim2wl[(p["metadata"]["namespace"],c)].add(owner(p))

for pv,node in sorted(stale.items(), key=lambda x:(x[1],x[0])):
    cr=pv2claim.get(pv) or {}
    key=(cr.get("namespace"),cr.get("name"))
    wls=sorted(claim2wl.get(key,()))
    if not wls:
        print(f"SKIP\t{node}\t{pv}\t{key[0]}/{key[1]}\tno running consumer")
        continue
    # all consumers of this PV must go down together
    spec=";".join(f"{key[0]}/{kind.lower()}/{name}" for kind,name in wls)
    print(f"CYCLE\t{node}\t{pv}\t{key[0]}/{key[1]}\t{spec}")
PY

ALLC=$(grep -c '^CYCLE' "$TMP/plan.txt" || true)
SKIP=$(grep -c '^SKIP' "$TMP/plan.txt" || true)
echo "engines still in a stale instance-manager: $((ALLC+SKIP))  (drainable: $ALLC, unmapped: $SKIP)"
[ "$((ALLC+SKIP))" = 0 ] && { echo "nothing to do — every engine is already in $TARGET"; exit 0; }

if [ ${#FILTERS[@]} -gt 0 ]; then
  : >"$TMP/filtered.txt"
  while IFS=$'\t' read -r verb node pv claim specs; do
    for f in "${FILTERS[@]}"; do
      # node name, exact namespace, or substring of the PVC / workload specs
      if [ "$f" = "$node" ] || [ "$f" = "${claim%%/*}" ] \
         || [[ "$claim" == *"$f"* ]] || [[ "$specs" == *"$f"* ]]; then
        printf '%s\t%s\t%s\t%s\t%s\n' "$verb" "$node" "$pv" "$claim" "$specs" >>"$TMP/filtered.txt"
        break
      fi
    done
  done < "$TMP/plan.txt"
  mv "$TMP/filtered.txt" "$TMP/plan.txt"
  TOTAL=$(grep -c '^CYCLE' "$TMP/plan.txt" || true)
  echo "filters [${FILTERS[*]}] -> $TOTAL of $ALLC volume(s) selected"
  [ "$TOTAL" = 0 ] && { echo "no volume matched — nothing to do"; exit 0; }
else
  TOTAL=$ALLC
fi

echo
awk -F'\t' '{printf "  %-6s %-6s %-42s %s\n", $1, $2, $4, $5}' "$TMP/plan.txt"

if [ "$MODE" != drain ]; then
  echo
  if [ ${#FILTERS[@]} -gt 0 ]; then
    echo "(read-only. rerun as: drain ${FILTERS[*]})"
  else
    echo "(read-only. rerun with 'drain' to cycle all of these, or pass filters e.g. 'drain node1' / 'drain media')"
  fi
  exit 0
fi

cycle() {  # pv, "ns/kind/name;ns/kind/name"
  local pv="$1" specs="$2" i=0 j=0
  local -a saved=()
  echo "== $pv  ($specs)"
  IFS=';' read -ra items <<<"$specs"
  # Validate every consumer FIRST. Scaling as we go would leave an already
  # scaled-down workload stranded at 0 when a later one turns out unscalable
  # (e.g. a volume shared with a running CronJob Job).
  for it in "${items[@]}"; do
    IFS='/' read -r ns kind name <<<"$it"
    if [ "$kind" != deployment ] && [ "$kind" != statefulset ]; then
      echo "   !! $it is a $kind, not scalable — skipping this volume, nothing touched."
      echo "      (re-run once it is gone; a CronJob Job holding a shared RWO volume is the usual cause)"
      return 1
    fi
  done
  for it in "${items[@]}"; do
    IFS='/' read -r ns kind name <<<"$it"
    local r; r=$(k -n "$ns" get "$kind/$name" -o jsonpath='{.spec.replicas}')
    saved+=("$it=$r")
    k -n "$ns" scale "$kind/$name" --replicas=0 >/dev/null
    echo "   scaled down $it (was $r)"
  done
  until [ "$(k -n "$NS" get volumes.longhorn.io "$pv" -o jsonpath='{.status.state}' 2>/dev/null)" = detached ] || [ $i -ge 90 ]; do
    i=$((i+1)); sleep 2
  done
  if [ $i -ge 90 ]; then
    echo "   !! never detached after 180s — restoring and skipping"
  else
    echo "   detached after $((i*2))s"
  fi
  for s in "${saved[@]}"; do
    local it=${s%=*} r=${s#*=}
    IFS='/' read -r ns kind name <<<"$it"
    k -n "$ns" scale "$kind/$name" --replicas="$r" >/dev/null
  done
  until [ "$(k -n "$NS" get volumes.longhorn.io "$pv" -o jsonpath='{.status.state}' 2>/dev/null)" = attached ] || [ $j -ge 90 ]; do
    j=$((j+1)); sleep 2
  done
  local now
  now=$(k -n "$NS" get instancemanagers.longhorn.io -o json | python3 -c '
import json,sys
pv=sys.argv[1]
for m in json.load(sys.stdin)["items"]:
    for e in (m["status"].get("instanceEngines") or {}):
        if e.startswith(pv): print(m["spec"]["image"].split(":")[-1])
' "$pv")
  echo "   reattached after $((j*2))s, engine now in instance-manager ${now:-?}"
}

echo
while IFS=$'\t' read -r verb node pv claim specs; do
  [ "$verb" = CYCLE ] || continue
  cycle "$pv" "$specs" || true
done < "$TMP/plan.txt"

echo
echo "remaining stale instance-managers:"
k -n "$NS" get instancemanagers.longhorn.io \
  -o custom-columns=NODE:.spec.nodeID,IMAGE:.spec.image,STATE:.status.currentState
