#!/usr/bin/env bash
# Step 6 — After the bake: promote addons to the recommended versions for
# TARGET_VERSION, validating that customized configuration survives.
set -euo pipefail
source "$(dirname "$0")/../config.env"

for ADDON in vpc-cni coredns kube-proxy; do
  DEFAULT_VERSION=$(aws eks describe-addon-versions --region "${AWS_REGION}" \
    --kubernetes-version "${TARGET_VERSION}" --addon-name "${ADDON}" \
    --query 'addons[0].addonVersions[?compatibilities[0].defaultVersion==`true`].addonVersion | [0]' \
    --output text)
  echo "=== ${ADDON} -> ${DEFAULT_VERSION} (default for ${TARGET_VERSION}) ==="
  aws eks update-addon --region "${AWS_REGION}" --cluster-name "${CLUSTER_NAME}" \
    --addon-name "${ADDON}" --addon-version "${DEFAULT_VERSION}" \
    --resolve-conflicts PRESERVE
done

echo
echo "Waiting for addons to settle..."
sleep 30
aws eks list-addons --region "${AWS_REGION}" --cluster-name "${CLUSTER_NAME}" --output table

echo
echo "Validate custom addon configuration survived (PRESERVE strategy), then"
echo "release the node rotation: scripts/07-release-rotation.sh"
