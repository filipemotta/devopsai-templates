#!/usr/bin/env bash
# Step 2 — Upgrade what must precede the control plane.
#   a) Karpenter controller/CRDs, IF the current version does not support TARGET_VERSION
#      (check https://karpenter.sh/docs/upgrading/compatibility/ — upgrade via
#      terraform variable karpenter_version + terraform apply, or helm upgrade).
#   b) Addons to versions compatible with BOTH current and target versions,
#      so the cluster can sit comfortably in the mixed bake state.
set -euo pipefail
source "$(dirname "$0")/../config.env"

for ADDON in vpc-cni coredns kube-proxy; do
  echo "=== ${ADDON}: versions compatible with ${CURRENT_VERSION} ==="
  aws eks describe-addon-versions --region "${AWS_REGION}" \
    --kubernetes-version "${CURRENT_VERSION}" --addon-name "${ADDON}" \
    --query 'addons[].addonVersions[].{version:addonVersion,default:compatibilities[0].defaultVersion}' \
    --output table
  echo "=== ${ADDON}: versions compatible with ${TARGET_VERSION} ==="
  aws eks describe-addon-versions --region "${AWS_REGION}" \
    --kubernetes-version "${TARGET_VERSION}" --addon-name "${ADDON}" \
    --query 'addons[].addonVersions[].{version:addonVersion,default:compatibilities[0].defaultVersion}' \
    --output table
  echo "Pick a version that appears in BOTH tables, then apply, e.g.:"
  echo "  aws eks update-addon --region ${AWS_REGION} --cluster-name ${CLUSTER_NAME} \\"
  echo "    --addon-name ${ADDON} --addon-version <cross-compatible-version> \\"
  echo "    --resolve-conflicts PRESERVE"
  echo "  (PRESERVE keeps customized configuration from being overwritten)"
  echo
done

echo "Final versions for ${TARGET_VERSION} are promoted AFTER the bake, in 06-finalize-addons.sh."
