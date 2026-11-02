#!/bin/bash
# /opt/drift/drift-scan.sh: read-only plan in every root module under envs/*/
# Prints ONE JSON with no attribute values; the agent never reads the raw plan.
set -uo pipefail
repo="${DRIFT_REPO:-/workspace/infra}"
work="${DRIFT_WORK:-/workspace/drift}"
mkdir -p "$work/report" "$work/logs"
export TF_VAR_plan_only=true TF_IN_AUTOMATION=1

for dir in "$repo"/envs/*/; do
  ws=$(basename "$dir")
  log="$work/logs/$ws.log"
  if ! terraform -chdir="$dir" init -input=false -lockfile=readonly -no-color >"$log" 2>&1; then
    status=init_error
  else
    # -lock=false: the plan-only role cannot write the lock (DynamoDB or .tflock in S3)
    terraform -chdir="$dir" plan -lock=false -input=false -no-color \
      -detailed-exitcode -out=tfplan >>"$log" 2>&1
    case $? in 0) status=clean ;; 2) status=changes ;; *) status=plan_error ;; esac
  fi

  if [ "$status" = changes ]; then
    terraform -chdir="$dir" show -json tfplan \
      | jq --arg ws "$ws" -f /opt/drift/summarize.jq >"$work/report/$ws.json"
  else
    # on error, only the tail of the log (provider message, no diff)
    tail -n 15 "$log" | jq -Rs --arg ws "$ws" --arg st "$status" \
      '{workspace: $ws, status: $st, drift: [], pending: [],
        error_tail: (if $st == "clean" then null else . end)}' >"$work/report/$ws.json"
  fi
  rm -f "$dir/tfplan"
done

jq -s '{generated_at: (now | todate), workspaces: .}' "$work"/report/*.json
