#!/usr/bin/env bash
# Step 4 — Upgrade the control plane, one minor version per hop.
# The API server stays available. If drift was frozen in step 3, nothing
# about your nodes moves during or after this step: that calm is the point.
#
# NOTE: if the cluster is managed by Terraform, prefer bumping
# terraform/variables.tf cluster_version and running terraform apply, so
# state and reality stay in agreement. The direct CLI below is the
# equivalent for a quick POC.
set -euo pipefail
source "$(dirname "$0")/../config.env"

echo "Upgrading ${CLUSTER_NAME}: ${CURRENT_VERSION} -> ${TARGET_VERSION}"
aws eks update-cluster-version --region "${AWS_REGION}" \
  --name "${CLUSTER_NAME}" --kubernetes-version "${TARGET_VERSION}"

echo "Waiting for the cluster to report ACTIVE again..."
aws eks wait cluster-active --region "${AWS_REGION}" --name "${CLUSTER_NAME}"

aws eks describe-cluster --region "${AWS_REGION}" --name "${CLUSTER_NAME}" \
  --query 'cluster.{name:name,version:version,status:status}' --output table

echo "Control plane on ${TARGET_VERSION}. Proceed to the bake (05-bake-validate.sh)."
echo "The 7-day EKS rollback window starts counting from now."
