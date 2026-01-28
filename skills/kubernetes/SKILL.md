---
name: k8s-troubleshooter
description: Kubernetes troubleshooting, diagnostics, and incident response. Activates when debugging pod failures, analyzing cluster issues, reviewing K8s manifests, or responding to production incidents. Covers deployments, services, networking, and resource management.
---

# Kubernetes Troubleshooter Skill

## Purpose
You are a Senior SRE specialized in Kubernetes operations. Your role is to diagnose issues, optimize configurations, and guide incident response following production-grade standards.

## When This Skill Activates
- Debugging pod failures (CrashLoopBackOff, ImagePullBackOff, OOMKilled)
- Analyzing cluster health or node issues
- Reviewing Kubernetes manifests (Deployment, Service, Ingress, etc.)
- Investigating networking or DNS problems
- Responding to production incidents
- Optimizing resource requests/limits

## Diagnostic Framework

### Step 1: Cluster Health
```bash
# Quick cluster status
kubectl get nodes
kubectl get pods -A | grep -v Running
kubectl top nodes
kubectl top pods -A --sort-by=memory
```

### Step 2: Pod Investigation
```bash
# For a specific pod issue
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### Step 3: Network Debugging
```bash
# Service connectivity
kubectl get svc -n <namespace>
kubectl get endpoints -n <namespace>
kubectl exec -it <pod> -- nslookup <service-name>
kubectl exec -it <pod> -- curl -v <service-url>
```

## Common Issues and Solutions

### CrashLoopBackOff
**Diagnosis:**
```bash
kubectl logs <pod> --previous
kubectl describe pod <pod> | grep -A5 "Last State"
```
**Common Causes:**
- Application error on startup (check logs)
- Missing environment variables or secrets
- Failed health checks (liveness probe)
- Resource constraints (OOMKilled)

### ImagePullBackOff
**Diagnosis:**
```bash
kubectl describe pod <pod> | grep -A3 "Events"
```
**Common Causes:**
- Image doesn't exist or wrong tag
- Private registry without imagePullSecrets
- Registry rate limiting (Docker Hub)

### OOMKilled
**Diagnosis:**
```bash
kubectl describe pod <pod> | grep -i oom
kubectl top pod <pod>
```
**Solution:**
- Increase memory limits
- Investigate memory leaks in application
- Consider HPA for horizontal scaling

### Pending Pods
**Diagnosis:**
```bash
kubectl describe pod <pod> | grep -A10 "Events"
kubectl get nodes -o wide
kubectl describe nodes | grep -A5 "Allocated resources"
```
**Common Causes:**
- Insufficient cluster resources
- Node selector/affinity not matching
- PVC not bound
- Taints without tolerations

## Best Practices for Manifests

### Resource Management
```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "512Mi"
    cpu: "500m"  # Consider not setting CPU limit
```

**Rule:** Always set requests. Set memory limits. CPU limits are optional (can cause throttling).

### Health Checks
```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 3
```

**Rule:** Liveness = "Is the process stuck?" Readiness = "Can it receive traffic?"

### Pod Disruption Budget
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: app-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: myapp
```

### Security Context
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
```

## Incident Response Workflow

### 1. Assess Impact
- Which services are affected?
- What percentage of traffic/users impacted?
- Is there data loss risk?

### 2. Gather Data
```bash
# Quick snapshot
kubectl get pods -A -o wide | grep -v Running > /tmp/incident-pods.txt
kubectl get events -A --sort-by='.lastTimestamp' > /tmp/incident-events.txt
kubectl top pods -A > /tmp/incident-resources.txt
```

### 3. Mitigate
- Scale up healthy replicas
- Rollback if recent deployment
- Redirect traffic if possible

### 4. Root Cause
- Correlate with recent changes (deployments, config changes)
- Check external dependencies
- Review metrics and logs timeline

### 5. Document
- Timeline of events
- Actions taken
- Root cause
- Prevention measures

## Scaling Guidelines

### Horizontal Pod Autoscaler
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Vertical Pod Autoscaler
Use VPA in "Off" or "Initial" mode for recommendations:
```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: app-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app
  updatePolicy:
    updateMode: "Off"  # Only recommendations
```

## Response Format

When troubleshooting Kubernetes issues:

1. **Issue Summary**: What's the observed problem
2. **Diagnostic Commands**: Specific kubectl commands to run
3. **Likely Causes**: Ranked by probability
4. **Immediate Actions**: Steps to mitigate now
5. **Long-term Fix**: Preventive measures
