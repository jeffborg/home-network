#!/usr/bin/env bash
# unstick-longhorn.sh — find (and optionally clear) genuinely STUCK Longhorn rebuilds.
#
# Background: with concurrent-replica-rebuild-per-node-limit=1 (one rebuild slot
# per node), a rebuild that hangs never releases its slot, so every other rebuild
# queued on that node is blocked forever — you see "0 active rebuilds" while lots
# of volumes sit degraded. This finds the replica holding the slot so you can
# delete it (Longhorn then starts a fresh, clean rebuild from the healthy copy).
#
# A stuck rebuild = a replica that is running+started but its engine never
# engaged it (absent from replicaModeMap), on an otherwise-HEALTHY volume:
#   - the volume's engine is actually running (attached, not down/unknown),
#   - the volume is doing no op (no purge/rebuild/restore in progress),
#   - the replica's node is Ready.
#
# It samples TWICE, 15s apart, and reports only replicas stuck in BOTH samples,
# so a slow / just-starting rebuild is never flagged. Actively rebuilding,
# purging, healthy, or node-outage replicas are never touched.
#
# If any Longhorn node is NotReady the tool REFUSES to act by default: during a
# node outage replicas churn for legitimate reasons and are not "stuck" — fix
# the node first. Override with FORCE=1 only if you understand the risk.
#
#   ./scripts/unstick-longhorn.sh          # identify
#   ./scripts/unstick-longhorn.sh delete   # delete them to free the slot (safe)
#
# Uses the current kubectl context by default; override with LH_CONTEXT / LH_NS.
set -euo pipefail
NS=${LH_NS:-longhorn-system}; MODE=${1:-list}
CTX_ARG=(); [ -n "${LH_CONTEXT:-}" ] && CTX_ARG=(--context "$LH_CONTEXT")
k(){ kubectl "${CTX_ARG[@]}" "$@"; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# --- node-health guard: a stuck-rebuild hunt is only meaningful on a stable cluster ---
k -n "$NS" get nodes.longhorn.io -o json >"$TMP/n.json"
NOTREADY=$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(" ".join(n["metadata"]["name"] for n in d["items"] if next((c["status"] for c in n["status"]["conditions"] if c["type"]=="Ready"),"")!="True"))' "$TMP/n.json")
if [ -n "$NOTREADY" ]; then
  echo "⚠️  Longhorn node(s) NotReady:$NOTREADY"
  echo "    Replicas are churning due to a node outage — that is NOT a wedged rebuild."
  echo "    Bring the node(s) back first. (Set FORCE=1 to analyse anyway.)"
  [ "${FORCE:-0}" = 1 ] || exit 1
fi

sample() {   # emits: node <TAB> workload <TAB> volume <TAB> replica
  k -n "$NS" get engines.longhorn.io  -o json >"$TMP/e.json"
  k -n "$NS" get replicas.longhorn.io -o json >"$TMP/r.json"
  k get pv -o json >"$TMP/pv.json"
  python3 - "$TMP/e.json" "$TMP/r.json" "$TMP/pv.json" "$TMP/n.json" <<'PY'
import json,sys
eng=json.load(open(sys.argv[1])); rep=json.load(open(sys.argv[2]))
pv=json.load(open(sys.argv[3])); nod=json.load(open(sys.argv[4]))
friendly={}
for p in pv["items"]:
    cr=p.get("spec",{}).get("claimRef") or {}
    if cr: friendly[p["metadata"]["name"]]="%s/%s"%(cr.get("namespace","?"),cr.get("name","?"))
notready={n["metadata"]["name"] for n in nod["items"]
          if next((c["status"] for c in n["status"]["conditions"] if c["type"]=="Ready"),"")!="True"}
engaged=set(); busy=set(); eng_up=set()
for e in eng["items"]:
    s=e["status"]; vol=e["spec"].get("volumeName")
    engaged|=set((s.get("replicaModeMap") or {}).keys())
    if s.get("currentState")=="running": eng_up.add(vol)          # volume attached & healthy
    for k in ("rebuildStatus","purgeStatus","restoreStatus","snapshotCloneStatus"):
        for _,i in (s.get(k) or {}).items():
            if i.get("isRebuilding") or i.get("isPurging") or i.get("isRestoring") or i.get("state")=="in_progress":
                busy.add(vol)
for r in rep["items"]:
    n,st=r["metadata"]["name"],r["status"]; vol=r["spec"].get("volumeName"); node=r["spec"].get("nodeID")
    if (st.get("currentState")=="running" and st.get("started")
            and n not in engaged        # engine never engaged this replica
            and vol in eng_up           # volume's engine is actually running
            and vol not in busy         # volume is not doing any op
            and node not in notready):  # replica's node is healthy
        print("%s\t%s\t%s\t%s"%(node,friendly.get(vol,"-"),vol,n))
PY
}

sample | sort >"$TMP/a"; sleep 15; sample | sort >"$TMP/b"
comm -12 "$TMP/a" "$TMP/b" >"$TMP/stuck"     # stuck in BOTH samples
if [ ! -s "$TMP/stuck" ]; then echo "No stuck rebuilds. ✅"; exit 0; fi
echo "STUCK rebuilds (holding a rebuild slot, no progress):"
printf 'NODE\tWORKLOAD\tVOLUME\tREPLICA\n' | cat - "$TMP/stuck" | column -t -s$'\t'
if [ "$MODE" = delete ]; then
  echo; echo "Freeing slots by deleting the stuck replicas..."
  cut -f4 "$TMP/stuck" | xargs -r k -n "$NS" delete replica
fi
