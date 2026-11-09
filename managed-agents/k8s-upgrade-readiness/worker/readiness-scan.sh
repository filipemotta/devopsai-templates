#!/bin/bash
# readiness-scan.sh: read-only pre-upgrade scan, run inside the worker pod.
# Prints ONE JSON document with names, versions and counts only: no object bodies,
# no annotations, no env, no ConfigMap/Secret data. Tool output reaches the model,
# so the summary is the only thing the agent is told to read.
set -uo pipefail

TARGET="${TARGET_VERSION:?set TARGET_VERSION, e.g. 1.36}"      # from the ConfigMap
CLUSTER="${CLUSTER_NAME:?set CLUSTER_NAME}"
T_MINOR="${TARGET#*.}"
ERRF=$(mktemp)                     # command substitutions run in subshells: collect errors in a file
trap 'rm -f "$ERRF"' EXIT

kj() { local e; e=$(mktemp); kubectl "$@" -o json 2>"$e" \
         || { echo "kubectl $*: $(tail -c 300 "$e")" >>"$ERRF"; echo '{"items":[]}'; }; rm -f "$e"; }

# 1. Control plane and kubelet skew: after the upgrade, kubelets may be at most
#    3 minors older than kube-apiserver (version skew policy).
server_minor=$(kubectl version -o json 2>/dev/null | jq -r '.serverVersion.minor' | tr -dc '0-9')
nodes=$(kj get nodes | jq --argjson t "$T_MINOR" '
  [.items[] | {name: .metadata.name,
               kubelet: .status.nodeInfo.kubeletVersion,
               minor: (.status.nodeInfo.kubeletVersion | capture("^v1\\.(?<m>[0-9]+)").m | tonumber)}
   | select(.minor < ($t - 3))
   | {name, kubelet}]')

# 2. CRDs: stored versions that are no longer served, or served but deprecated.
crds=$(kj get crd | jq '
  [.items[] | . as $c
   | ([.spec.versions[] | select(.served) | .name]) as $served
   | ([.spec.versions[] | select(.deprecated == true) | .name]) as $dep
   | (.status.storedVersions // []) as $stored
   | {name: .metadata.name,
      stored_not_served: [$stored[] | select(. as $v | $served | index($v) | not)],
      stored_deprecated: [$stored[] | select(. as $v | $dep | index($v))]}
   | select((.stored_not_served | length) > 0 or (.stored_deprecated | length) > 0)]')

# 3. PDBs that will block a node drain right now.
pdbs=$(kj get pdb -A | jq '
  [.items[] | select((.status.expectedPods // 0) > 0 and (.status.disruptionsAllowed // 0) == 0)
   | {ns: .metadata.namespace, name: .metadata.name, expected: .status.expectedPods}]')

# 4. Fail-closed webhooks whose backing Service has no ready endpoint.
hooks='[]'
while IFS=$'\t' read -r kind name ns svc; do
  [ -z "$svc" ] && continue
  ready=$(kubectl get endpointslices -n "$ns" -l "kubernetes.io/service-name=$svc" -o json 2>/dev/null \
          | jq '[.items[].endpoints[]? | select(.conditions.ready == true)] | length')
  [ "${ready:-0}" -eq 0 ] && hooks=$(jq --arg k "$kind" --arg n "$name" --arg s "$ns/$svc" \
          '. + [{kind: $k, name: $n, service: $s}]' <<<"$hooks")
done < <( { kj get validatingwebhookconfigurations | jq -r '.items[] | .metadata.name as $n
              | .webhooks[] | select(.failurePolicy == "Fail" and .clientConfig.service != null)
              | ["validating", $n, .clientConfig.service.namespace, .clientConfig.service.name] | @tsv'
            kj get mutatingwebhookconfigurations | jq -r '.items[] | .metadata.name as $n
              | .webhooks[] | select(.failurePolicy == "Fail" and .clientConfig.service != null)
              | ["mutating", $n, .clientConfig.service.namespace, .clientConfig.service.name] | @tsv'
          } | sort -u )

# 5. Aggregated APIs that are down (break discovery, namespace deletion, kubectl).
apisvc=$(kj get apiservices | jq '[.items[]
  | select(any(.status.conditions[]?; .type == "Available" and .status != "True"))
  | .metadata.name]')

# 6. EKS upgrade insights for the target version (audit-log based: catches clients
#    still calling deprecated APIs, which reading live objects cannot).
insights='[]'
ids=$(aws eks list-insights --cluster-name "$CLUSTER" \
        --filter "{\"categories\":[\"UPGRADE_READINESS\"],\"kubernetesVersions\":[\"$TARGET\"],\"statuses\":[\"WARNING\",\"ERROR\",\"UNKNOWN\"]}" \
        --query 'insights[].id' --output text 2>>"$ERRF") || echo "aws eks list-insights failed" >>"$ERRF"
for id in $ids; do
  [ "$id" = "None" ] && continue
  one=$(aws eks describe-insight --cluster-name "$CLUSTER" --id "$id" --output json 2>/dev/null | jq '.insight | {
      name, status: .insightStatus.status, reason: .insightStatus.reason,
      deprecations: [.categorySpecificSummary.deprecationDetails[]? | {usage, replacedWith, stopServingVersion,
                     clients: [.clientStats[]? | {userAgent, numberOfRequestsLast30Days, lastRequestTime}]}],
      addons: [.categorySpecificSummary.addonCompatibilityDetails[]? | {name, compatibleVersions}],
      resources: [.resources[]? | .kubernetesResourceUri // .arn] | .[:20]}')
  [ -n "$one" ] && insights=$(jq --argjson o "$one" '. + [$o]' <<<"$insights")
done

# 7. EKS managed add-ons whose installed version is not offered for the target.
addons='[]'
for a in $(aws eks list-addons --cluster-name "$CLUSTER" --query 'addons[]' --output text 2>/dev/null); do
  cur=$(aws eks describe-addon --cluster-name "$CLUSTER" --addon-name "$a" --query 'addon.addonVersion' --output text 2>/dev/null)
  ok=$(aws eks describe-addon-versions --kubernetes-version "$TARGET" --addon-name "$a" \
        --query 'addons[0].addonVersions[].addonVersion' --output json 2>/dev/null | jq --arg c "$cur" 'index($c) != null')
  [ "$ok" != "true" ] && addons=$(jq --arg n "$a" --arg c "$cur" '. + [{name: $n, installed: $c}]' <<<"$addons")
done

jq -n --arg cluster "$CLUSTER" --arg target "$TARGET" --arg server "1.$server_minor" \
  --argjson nodes "$nodes" --argjson crds "$crds" --argjson pdbs "$pdbs" --argjson hooks "$hooks" \
  --argjson apisvc "$apisvc" --argjson insights "$insights" --argjson addons "$addons" \
  --argjson errors "$(jq -R . <"$ERRF" | jq -s 'map(select(. != ""))')" '
  {cluster: $cluster, server: $server, target: $target,
   skipped_minor: (($target | split(".")[1] | tonumber) - ($server | split(".")[1] | tonumber) > 1),
   kubelet_too_old: $nodes, crd_stored_versions: $crds, pdb_blocking_drain: $pdbs,
   failclosed_webhooks_down: $hooks, apiservices_unavailable: $apisvc,
   eks_insights: $insights, addons_not_offered_for_target: $addons, scan_errors: $errors}'
