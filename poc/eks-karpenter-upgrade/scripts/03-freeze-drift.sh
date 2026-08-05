#!/usr/bin/env bash
# Step 3 — Gate the rotation BEFORE touching the control plane.
#
# Why: the versioned AMI alias in the EC2NodeClass re-resolves when the
# cluster version changes, so the control plane hop can itself start the
# node rotation. Freezing the Drifted reason first makes releasing the
# rotation a separate, deliberate step (07-release-rotation.sh).
#
# Consolidation stays alive: the zero budget is scoped to Drifted only.
set -euo pipefail
source "$(dirname "$0")/../config.env"

kubectl apply -f "$(dirname "$0")/../manifests/nodepool-drift-frozen.yaml"

echo "Drift rotation frozen. Verify:"
kubectl get nodepool general -o jsonpath='{.spec.disruption.budgets}' | python3 -m json.tool
