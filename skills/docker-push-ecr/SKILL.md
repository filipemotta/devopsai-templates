---
name: docker-push-ecr
description: >
  Builds and pushes Docker images to Amazon ECR repositories. Use whenever the
  user asks to build and send images to ECR, push containers, upload an image
  to the registry or publish a Docker image to AWS, even without mentioning
  "docker-push-ecr" explicitly. Takes app-path and ECR-URI pairs as arguments;
  multiple pairs are supported in a single run.
---

## What this skill does

Runs the complete build and push pipeline for Docker images to Amazon ECR:

1. ECR login via AWS CLI
2. Docker build with `--platform=linux/amd64`
3. Docker push to the ECR repository
4. Verification that the image reached the registry

## Arguments

Takes pairs in the format `<app-path> <ecr-uri>`, separated by commas or on
separate lines:

```
/docker-push-ecr apps/backend/my-api 123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp/production/backend:v1.0.0
```

```
/docker-push-ecr apps/backend/my-api <uri-1>, apps/frontend/my-web <uri-2>
```

If the tag is missing from the URI, use the short git SHA of the current
commit as the tag (immutable tags beat `latest`; in production the tag comes
from the CI pipeline).

## Workflow

### Step 1 — Parse arguments

For each pair:
- Validate that the path exists and contains a `Dockerfile`
- Validate the URI format: `<account>.dkr.ecr.<region>.amazonaws.com/<repo>:<tag>`
- Extract the region and account ID from the URI

If any validation fails, report the error and skip that pair.

### Step 2 — ECR login

Log in using the region extracted from the URI. Login is needed only once per
region, even with multiple images:

```bash
aws ecr get-login-password --region <region> | \
  docker login --username AWS --password-stdin <account>.dkr.ecr.<region>.amazonaws.com
```

If the login fails, stop and report (usually AWS credentials not configured).

### Step 3 — Build and push (per pair)

```bash
cd <app-path>
docker build --platform=linux/amd64 -t <full-uri> .
docker push <full-uri>
```

Always use `--platform=linux/amd64` to guarantee compatibility with x86_64
cluster nodes; this is essential on Apple Silicon (arm64) machines. If your
cluster runs Graviton (arm64) nodes, adjust the platform accordingly.

If a build fails, show the error and continue to the next pair (don't abort
everything).

### Step 4 — Verify

```bash
aws ecr describe-images \
  --repository-name <repo-name> \
  --image-ids imageTag=<tag> \
  --region <region> \
  --query 'imageDetails[0].{pushedAt:imagePushedAt,size:imageSizeInBytes,digest:imageDigest}' \
  --output table
```

### Step 5 — Report the result

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Docker Push ECR — Result
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ ECR Login OK (us-east-1)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Image 1: myapp/production/backend:v1.0.0
  App:    apps/backend/my-api
  ✓ Build OK (linux/amd64)
  ✓ Push OK
  ✓ Verified in ECR
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If any step fails, mark it with `✗` and show the error message.

## Important notes

- Do not clean up local images automatically; the user may want them for
  debugging
- If Docker is not running, tell the user before attempting any operation
- This skill covers the development inner loop. In production, build and push
  belong to the CI pipeline (OIDC + image scan before push + GitOps tag bump)
