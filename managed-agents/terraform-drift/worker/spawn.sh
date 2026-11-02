#!/bin/bash
# /opt/drift/spawn.sh: the poller calls this script once per claimed session.
# The work item arrives as JSON on stdin; ANTHROPIC_SESSION_ID and the other variables come from the poller.
set -euo pipefail

ANTHROPIC_WORK_SECRET="$(jq -r '.secret // empty')"   # required to mount the memory store
export ANTHROPIC_WORK_SECRET

run="/srv/drift/$ANTHROPIC_SESSION_ID"
mkdir -p "$run"

# 1. Code: shallow clone of main with a READ-ONLY deploy key that stays on the host (never in the container)
GIT_SSH_COMMAND="ssh -i /etc/drift/deploy_key -o IdentitiesOnly=yes" \
  git clone --quiet --depth 1 --branch main git@github.com:acme/infra.git "$run/infra"

# 2. Credential: 1 hour in the plan-only role, the only one the instance profile can assume
creds=$(aws sts assume-role \
  --role-arn arn:aws:iam::111122223333:role/terraform-plan-readonly \
  --role-session-name "drift-${ANTHROPIC_SESSION_ID: -20}" \
  --duration-seconds 3600 --query Credentials --output json)
export AWS_ACCESS_KEY_ID=$(jq -r .AccessKeyId <<<"$creds")
export AWS_SECRET_ACCESS_KEY=$(jq -r .SecretAccessKey <<<"$creds")
export AWS_SESSION_TOKEN=$(jq -r .SessionToken <<<"$creds")

# 3. One disposable container per run; the "drift-egress" network only reaches AWS and Anthropic
exec docker run --rm --user 1000:1000 --cap-drop ALL --security-opt no-new-privileges \
  --network drift-egress \
  -e ANTHROPIC_SESSION_ID -e ANTHROPIC_ENVIRONMENT_KEY -e ANTHROPIC_WORK_ID \
  -e ANTHROPIC_ENVIRONMENT_ID -e ANTHROPIC_BASE_URL -e ANTHROPIC_WORK_SECRET \
  -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_SESSION_TOKEN -e AWS_REGION=us-east-1 \
  -v "$run":/workspace \
  drift-runner:1.4.0
