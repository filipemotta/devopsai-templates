#!/usr/bin/env bash
# Step 7 — Release the rotation and watch drift do its work.
# Restores the normal budgets from nodepool.yaml (10% Drifted, 10%
# consolidation, scheduled freeze). With the alias now resolving to the
# TARGET_VERSION build, existing nodes are Drifted and rotate at the pace
# the budgets allow. Karpenter simulates scheduling first and only creates
# replacement capacity when the evicted pods actually need it.
set -euo pipefail
source "$(dirname "$0")/../config.env"

kubectl apply -f "$(dirname "$0")/../manifests/nodepool.yaml"
echo "Budgets restored. Drift rotation is live."
echo
echo "Watch in two terminals (article step six):"
echo "  Terminal 1: kubectl get nodes -w -o custom-columns='NODE:.metadata.name,KUBELET:.status.nodeInfo.kubeletVersion,READY:.status.conditions[-1].type'"
echo "  Terminal 2: kubectl get pods -A --field-selector=status.phase=Pending -w"
echo
echo "Useful signals while it runs (article: alarms, not attention):"
echo "  kubectl get nodeclaims                          # churn pace"
echo "  kubectl get events -A --field-selector reason=Drifted --sort-by=.lastTimestamp | tail"
echo "  kubectl get pdb -A                              # ALLOWED DISRUPTIONS column: 0 for long = stall"
echo
echo "Take notes for step 8: convergence time, PDB stalls, anything that paged."
