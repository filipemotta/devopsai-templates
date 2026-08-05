#!/usr/bin/env bash
# Step 1 — Preflight (article: "fix every removal; deprecations can wait, removals cannot")
# Three angles on the same question:
#   pluto  -> what you INTEND to deploy (manifests, Helm releases)
#   kubent -> what is ACTUALLY running (live objects, including archaeology)
#   EKS upgrade insights -> OBSERVED traffic (deprecated API calls, last 30 days)
set -euo pipefail
source "$(dirname "$0")/../config.env"

echo "=== [1/4] pluto: scanning repository manifests against k8s v${TARGET_VERSION}.0 ==="
pluto detect-files -d "$(dirname "$0")/../manifests" \
  --target-versions "k8s=v${TARGET_VERSION}.0" -o wide || true

echo
echo "=== [2/4] pluto: scanning installed Helm releases ==="
pluto detect-helm -o wide --target-versions "k8s=v${TARGET_VERSION}.0" || true

echo
echo "=== [3/4] kubent: scanning live cluster objects ==="
# --exit-error makes this a proper CI gate: nonzero exit when findings exist.
kubent --target-version "${TARGET_VERSION}" --exit-error || {
  echo "!! kubent found deprecated APIs in live objects. Fix removals before proceeding."
}

echo
echo "=== [4/4] EKS upgrade insights: deprecated API calls observed by the API server ==="
aws eks list-insights --cluster-name "${CLUSTER_NAME}" --region "${AWS_REGION}" \
  --query 'insights[].{name:name,status:insightStatus.status,lastRefresh:lastRefreshTime}' \
  --output table

echo
echo "Also confirm before moving on (manual checklist):"
echo "  [ ] Release notes for ${TARGET_VERSION} read"
echo "  [ ] Karpenter ${KARPENTER_VERSION} supports ${TARGET_VERSION} (compatibility matrix)"
echo "  [ ] Addon versions compatible with BOTH ${CURRENT_VERSION} and ${TARGET_VERSION} identified (see 02-pre-upgrades.sh)"
echo "  [ ] Webhooks/operators that must understand the new API identified"
echo "  [ ] PDBs, capacity headroom and topology spread confirmed on workloads that matter"
