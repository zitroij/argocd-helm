# Environment-Specific Configurations

This directory contains environment-specific configurations for deploying the sample application using ArgoCD.

## Directory Structure

```
environments/
├── dev/
│   └── values.yaml        # Development environment values
├── staging/
│   └── values.yaml        # Staging environment values
├── prod/
│   └── values.yaml        # Production environment values
└── README.md              # This file
```

**Note**: ArgoCD Application manifests are located in `argocd/environments/` directory, following GitOps best practices for separation of concerns.

## Environment Configurations

### Development (dev/)
- **Namespace**: `sample-app-dev`
- **Replicas**: 1
- **Image Tag**: `latest`
- **Log Level**: `debug`
- **Branch**: `develop`
- **Auto-Sync**: Enabled
- **Database**: `postgres-dev.default.svc.cluster.local`

### Staging (staging/)
- **Namespace**: `sample-app-staging`
- **Replicas**: 2
- **Image Tag**: `1.21`
- **Log Level**: `info`
- **Branch**: `main`
- **Auto-Sync**: Enabled
- **Database**: `postgres-staging.default.svc.cluster.local`

### Production (prod/)
- **Namespace**: `sample-app-prod`
- **Replicas**: 3
- **Image Tag**: `1.21`
- **Log Level**: `info`
- **Branch**: `main`
- **Auto-Sync**: Disabled (manual sync required)
- **Database**: `postgres.default.svc.cluster.local`

## Deployment Instructions

### Deploy Individual Environment

```bash
# Deploy to development
oc apply -f argocd/environments/dev/application.yaml

# Deploy to staging
oc apply -f argocd/environments/staging/application.yaml

# Deploy to production
oc apply -f argocd/environments/prod/application.yaml
```

### Deploy All Environments at Once

Use the ApplicationSet to deploy all environments:

```bash
oc apply -f argocd/applicationset.yaml
```

This will create ArgoCD Applications for all three environments automatically.

### Verify Deployments

```bash
# List all applications
oc get applications -n openshift-gitops

# Check specific environment
oc get application sample-app-dev -n openshift-gitops
oc get application sample-app-staging -n openshift-gitops
oc get application sample-app-prod -n openshift-gitops

# View resources in each namespace
oc get all -n sample-app-dev
oc get all -n sample-app-staging
oc get all -n sample-app-prod
```

## Customizing Environments

### Modify Environment Values

Edit the `values.yaml` file in the respective environment directory:

```bash
# Edit dev values
vi environments/dev/values.yaml

# Commit and push changes
git add environments/dev/values.yaml
git commit -m "Update dev configuration"
git push
```

ArgoCD will automatically sync the changes (if auto-sync is enabled).

### Modify ArgoCD Application Settings

Edit the `application.yaml` file in the respective environment directory:

```bash
# Edit dev application
vi environments/dev/application.yaml

# Apply changes
oc apply -f environments/dev/application.yaml
```

## Environment Promotion Workflow

### Typical Workflow

1. **Development**: 
   - Developers push changes to `develop` branch
   - Auto-sync deploys to dev environment
   - Test and validate changes

2. **Staging**:
   - Merge `develop` to `main` branch
   - Auto-sync deploys to staging environment
   - Run integration tests and QA

3. **Production**:
   - Manual sync required for production
   - Review changes in ArgoCD UI
   - Approve and sync to production

### Manual Sync to Production

```bash
# Using oc CLI
oc patch application sample-app-prod -n openshift-gitops \
  --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'

# Or use ArgoCD CLI
argocd app sync sample-app-prod

# Or use ArgoCD UI
# Navigate to sample-app-prod → Click "Sync" button
```

## Switching Between Environments

### Test Locally Before Deploying

```bash
# Test dev values
helm template sample-app . -f environments/dev/values.yaml

# Test staging values
helm template sample-app . -f environments/staging/values.yaml

# Test prod values
helm template sample-app . -f environments/prod/values.yaml
```

### Compare Environments

```bash
# Compare dev and staging
diff environments/dev/values.yaml environments/staging/values.yaml

# Compare staging and prod
diff environments/staging/values.yaml environments/prod/values.yaml
```

## Troubleshooting

### Application Not Syncing

```bash
# Check application status
oc describe application sample-app-dev -n openshift-gitops

# Check sync status
oc get application sample-app-dev -n openshift-gitops -o jsonpath='{.status.sync.status}'

# View sync errors
oc get application sample-app-dev -n openshift-gitops -o jsonpath='{.status.conditions}'
```

### Wrong Values Being Used

Verify the values file path in the application:

```bash
oc get application sample-app-dev -n openshift-gitops -o jsonpath='{.spec.source.helm.valueFiles}'
```

Should output: `["environments/dev/values.yaml"]`

### Manual Sync Not Working

Check if the application has automated sync enabled:

```bash
oc get application sample-app-prod -n openshift-gitops -o jsonpath='{.spec.syncPolicy.automated}'
```

For production, this should be empty (manual sync).

## Best Practices

1. **Keep environments consistent**: Use the same base configuration with environment-specific overrides
2. **Version control**: Always commit changes to Git before applying
3. **Test in lower environments**: Validate changes in dev/staging before production
4. **Use branches**: Different branches for different environments (develop → dev, main → staging/prod)
5. **Manual production sync**: Require manual approval for production deployments
6. **Document changes**: Update this README when adding new environments or changing configurations
7. **Monitor deployments**: Watch ArgoCD sync status after changes
8. **Backup configurations**: Keep backups of working configurations

## Adding New Environments

To add a new environment (e.g., `qa`):

1. Create directory:
   ```bash
   mkdir -p environments/qa
   ```

2. Create values file:
   ```bash
   cp environments/staging/values.yaml environments/qa/values.yaml
   # Edit as needed
   ```

3. Create application file:
   ```bash
   cp environments/staging/application.yaml environments/qa/application.yaml
   # Update name, namespace, and values file path
   ```

4. Update ApplicationSet (optional):
   ```yaml
   - env: qa
     namespace: sample-app-qa
     branch: main
     valuesFile: environments/qa/values.yaml
     autoSync: "true"
   ```

5. Deploy:
   ```bash
   oc apply -f environments/qa/application.yaml