---
name: argo-diff
description: Read-only pre-sync diff for GitOps PRs. Answers "what actually changes in the cluster if this PR lands?". Usage: /argo-diff [overlay-path]
---

Answer "what changes in the cluster if this change lands?" for the
overlay in $1 (default: the overlay affected by the current diff).
This skill is strictly read-only: never modify files, never sync.

## Steps

1. Identify the affected overlay(s) from the working tree diff
   (or use $1 if provided).
2. Run `kustomize build <overlay>` to confirm the manifests render.
   A rendering error ends the analysis: report it as a BLOCKER.
3. Run `argocd app diff --local <overlay>` against the corresponding
   Application to get the rendered, cluster-level diff.
4. Translate the rendered diff into impact language, grouped as:
   - **Created**: new resources that will appear.
   - **Changed**: fields that change, with before → after values for
     anything operational (image tags, replicas, resources, probes).
   - **Deleted**: resources that will be REMOVED. If the Application
     has `prune: true`, flag each deletion prominently: this is the
     highest-risk category.
5. Close with a one-line verdict: safe to merge / needs attention
   (list) / blocked (rendering error or unconfirmed deletion).
