#!/usr/bin/env bash
# Step 5 — Bake: control plane on N+1, nodes still on N.
#
# This mixed state is fully supported by the version skew policy (kubelet
# may run up to three minors behind the API server) and it is the CHEAPEST
# rollback point of the entire upgrade: reverting the control plane now
# requires no node rollback at all, and the 7-day EKS rollback window
# exists precisely for this period. Do not rush past the stage where
# mistakes are cheapest. In real fleets, bake for hours to days.
set -euo pipefail
source "$(dirname "$0")/../config.env"

echo "=== Version skew check: control plane vs kubelets ==="
aws eks describe-cluster --region "${AWS_REGION}" --name "${CLUSTER_NAME}" \
  --query 'cluster.version' --output text
kubectl get nodes -o custom-columns='NODE:.metadata.name,KUBELET:.status.nodeInfo.kubeletVersion,READY:.status.conditions[-1].type'

echo
echo "=== Controllers healthy? ==="
kubectl get deploy -n kube-system
kubectl get pods -n kube-system --field-selector=status.phase!=Running 2>/dev/null || true

echo
echo "=== Karpenter controller logs (errors only, last 15m) ==="
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter --since=15m 2>/dev/null | grep -i error || echo "no errors logged"

echo
echo "=== Webhooks answering? ==="
kubectl get validatingwebhookconfigurations,mutatingwebhookconfigurations -o name

echo
echo "=== Fresh insight findings against the new API server? ==="
aws eks list-insights --cluster-name "${CLUSTER_NAME}" --region "${AWS_REGION}" \
  --query 'insights[].{name:name,status:insightStatus.status}' --output table

echo
echo "=== Sample workload still healthy? ==="
kubectl get deploy sample-web -o wide
kubectl get pdb sample-web

echo
echo "Bake checklist before proceeding to 06:"
echo "  [ ] No controller crash loops, no webhook failures"
echo "  [ ] No new error spikes in platform or application telemetry"
echo "  [ ] No insight findings against the new API server"
echo "  [ ] Soak time elapsed (POC: 30+ min; real fleet: hours to days, inside the 7-day window)"
