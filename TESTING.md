# Testing Guide

This guide explains how to test the Helm chart locally before deploying with ArgoCD.

## Prerequisites

- Helm 3.x installed
- kubectl or oc CLI configured
- Access to a Kubernetes/OpenShift cluster

## Local Testing Methods

### 1. Lint the Chart

Check for syntax errors and best practices:

```bash
# Using Makefile
make lint

# Or directly with Helm
helm lint .
```

Expected output:
```
==> Linting .
[INFO] Chart.yaml: icon is recommended
1 chart(s) linted, 0 chart(s) failed
```

### 2. Template Rendering

Generate Kubernetes manifests without installing:

```bash
# Render with default values
make template

# Or with Helm
helm template sample-app .

# Save to file for inspection
helm template sample-app . > rendered-manifests.yaml
```

### 3. Dry Run Installation

Simulate installation without actually deploying:

```bash
helm install sample-app . --dry-run --debug -n sample-app
```

This shows:
- Rendered templates
- Values being used
- Any errors in template logic

### 4. Test Different Value Files

```bash
# Test dev values
make template-dev

# Test staging values
make template-staging

# Test with custom values
helm template sample-app . -f custom-values.yaml
```

### 5. Verify Specific Values

Test with inline value overrides:

```bash
helm template sample-app . \
  --set replicaCount=5 \
  --set image.tag=1.22 \
  --set service.type=LoadBalancer
```

## Installation Testing

### Install to Test Namespace

```bash
# Create test namespace
oc create namespace helm-test

# Install chart
helm install sample-app-test . -n helm-test

# Check status
helm status sample-app-test -n helm-test

# List all resources
oc get all -n helm-test
```

### Verify Resources

```bash
# Check deployment
oc get deployment -n helm-test
oc describe deployment sample-app-test -n helm-test

# Check pods
oc get pods -n helm-test
oc logs -l app.kubernetes.io/name=sample-app -n helm-test

# Check configmaps
oc get configmap -n helm-test
oc describe configmap sample-app-test-app-config -n helm-test

# Check service
oc get service -n helm-test
```

### Test Upgrades

```bash
# Modify values.yaml (e.g., change replicaCount to 3)

# Upgrade the release
helm upgrade sample-app-test . -n helm-test

# Check revision history
helm history sample-app-test -n helm-test

# Rollback if needed
helm rollback sample-app-test 1 -n helm-test
```

### Cleanup

```bash
# Uninstall release
helm uninstall sample-app-test -n helm-test

# Delete namespace
oc delete namespace helm-test
```

## ArgoCD Testing

### Test ArgoCD Application Locally

Before applying to cluster, validate the manifest:

```bash
# Validate YAML syntax
oc apply -f argocd/application.yaml --dry-run=client

# Check for errors
oc apply -f argocd/application.yaml --dry-run=server
```

### Test in Development Environment

```bash
# Deploy to dev
make deploy-argocd-dev

# Watch sync status
watch oc get application sample-app-dev -n openshift-gitops

# Check application details
oc describe application sample-app-dev -n openshift-gitops

# View deployed resources
oc get all -n sample-app-dev
```

### Test Sync Behavior

```bash
# Make a change to values.yaml
# Commit and push to Git

# Watch ArgoCD auto-sync (if enabled)
watch oc get application sample-app-dev -n openshift-gitops

# Or manually trigger sync
make sync
```

## Automated Testing

### Create Test Script

```bash
#!/bin/bash
# test-chart.sh

set -e

echo "=== Testing Helm Chart ==="

echo "1. Linting chart..."
helm lint .

echo "2. Testing template rendering..."
helm template test-release . > /dev/null

echo "3. Testing with dev values..."
helm template test-release . -f values-dev.yaml > /dev/null

echo "4. Testing with staging values..."
helm template test-release . -f values-staging.yaml > /dev/null

echo "5. Validating ArgoCD manifests..."
oc apply -f argocd/application.yaml --dry-run=client
oc apply -f argocd/application-dev.yaml --dry-run=client
oc apply -f argocd/applicationset.yaml --dry-run=client

echo "✓ All tests passed!"
```

Make it executable and run:

```bash
chmod +x test-chart.sh
./test-chart.sh
```

## Common Issues and Solutions

### Issue: Template Rendering Fails

```bash
# Check for syntax errors
helm lint .

# Debug specific template
helm template sample-app . --debug
```

### Issue: Values Not Applied

```bash
# Verify values are being used
helm template sample-app . --debug | grep -A 5 "replicaCount"

# Check value precedence
helm template sample-app . -f values.yaml -f values-dev.yaml --set replicaCount=10
```

### Issue: ArgoCD Not Syncing

```bash
# Check application status
oc get application sample-app -n openshift-gitops -o yaml

# View sync errors
oc describe application sample-app -n openshift-gitops

# Check ArgoCD logs
oc logs -n openshift-gitops -l app.kubernetes.io/name=openshift-gitops-application-controller
```

### Issue: Resources Not Created

```bash
# Check if namespace exists
oc get namespace sample-app

# Check ArgoCD permissions
oc get rolebinding -n sample-app

# Verify sync policy
oc get application sample-app -n openshift-gitops -o jsonpath='{.spec.syncPolicy}'
```

## Performance Testing

### Test Resource Limits

```bash
# Install with specific resources
helm install sample-app . -n test \
  --set resources.limits.cpu=50m \
  --set resources.limits.memory=64Mi

# Monitor resource usage
oc top pods -n test
```

### Test Scaling

```bash
# Scale up
helm upgrade sample-app . -n test --set replicaCount=10

# Watch pods
watch oc get pods -n test

# Check resource distribution
oc get pods -n test -o wide
```

## Integration Testing

### Test with Real Database

1. Deploy a test database:
```bash
oc new-app postgresql-ephemeral -n test
```

2. Update values to point to test database:
```yaml
configMaps:
  database-config:
    data:
      DB_HOST: "postgresql.test.svc.cluster.local"
```

3. Deploy and test connectivity:
```bash
helm upgrade sample-app . -n test
oc exec -it deployment/sample-app -n test -- env | grep DB_
```

## Continuous Testing

Add to your CI/CD pipeline:

```yaml
# .github/workflows/test-helm.yml
name: Test Helm Chart
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: azure/setup-helm@v3
      - name: Lint chart
        run: helm lint .
      - name: Test templates
        run: |
          helm template test .
          helm template test . -f values-dev.yaml
          helm template test . -f values-staging.yaml
```

## Best Practices

1. **Always lint before committing**: `make lint`
2. **Test all value files**: Ensure each environment configuration works
3. **Use dry-run**: Test installations without affecting cluster
4. **Version control**: Tag releases and test specific versions
5. **Document changes**: Update CHANGELOG.md with each modification
6. **Test rollbacks**: Ensure you can rollback to previous versions
7. **Monitor resources**: Check CPU/memory usage after deployment
8. **Security scan**: Use tools like `helm-snyk` or `trivy` to scan for vulnerabilities

## Useful Commands Reference

```bash
# Quick verification
make verify

# Full test cycle
make lint && make template && make install

# Check everything
make status

# View logs
make logs

# Clean up
make clean