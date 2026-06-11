# ArgoCD Manifests

This directory contains ArgoCD Application manifests for deploying the Helm chart to different environments.

## Directory Structure

```
argocd/
├── applicationset.yaml           # ApplicationSet for all environments
├── environments/                 # Environment-specific Applications
│   ├── dev/
│   │   └── application.yaml     # Development environment
│   ├── staging/
│   │   └── application.yaml     # Staging environment
│   └── prod/
│       └── application.yaml     # Production environment
├── application.yaml              # Legacy (deprecated)
├── application-dev.yaml          # Legacy (deprecated)
└── README.md                     # This file
```

## Why Separate from Helm Values?

Following GitOps best practices, ArgoCD Application manifests are separated from Helm values because:

1. **Different Concerns**:
   - Helm values define **what** to deploy (application configuration)
   - ArgoCD Applications define **how** to deploy (deployment strategy)

2. **Different Teams**:
   - Application teams manage `environments/*/values.yaml`
   - Platform/DevOps teams manage `argocd/environments/*/application.yaml`

3. **Different Lifecycles**:
   - Application config changes frequently
   - Deployment strategy changes infrequently

4. **Access Control**:
   ```
   CODEOWNERS:
     /environments/    @app-team
     /argocd/         @platform-team
   ```

See [BEST_PRACTICES.md](../BEST_PRACTICES.md) for detailed explanation.

## Deployment Options

### Option 1: Deploy Individual Environments

Deploy specific environments one at a time:

```bash
# Development
oc apply -f environments/dev/application.yaml

# Staging
oc apply -f environments/staging/application.yaml

# Production
oc apply -f environments/prod/application.yaml
```

**Use when**: You want fine-grained control over each environment.

### Option 2: Deploy All Environments (ApplicationSet)

Deploy all environments at once using ApplicationSet:

```bash
oc apply -f applicationset.yaml
```

**Use when**: You want to manage all environments together with consistent configuration.

## Environment Configurations

### Development (`environments/dev/application.yaml`)
- **Namespace**: `sample-app-dev`
- **Branch**: `develop`
- **Values**: `environments/dev/values.yaml`
- **Auto-Sync**: ✅ Enabled
- **Purpose**: Active development and testing

### Staging (`environments/staging/application.yaml`)
- **Namespace**: `sample-app-staging`
- **Branch**: `main`
- **Values**: `environments/staging/values.yaml`
- **Auto-Sync**: ✅ Enabled
- **Purpose**: Pre-production testing and QA

### Production (`environments/prod/application.yaml`)
- **Namespace**: `sample-app-prod`
- **Branch**: `main` (or tagged release)
- **Values**: `environments/prod/values.yaml`
- **Auto-Sync**: ❌ Disabled (manual approval required)
- **Purpose**: Live production environment

## Customizing Applications

### Update Repository URL

Edit each application file and update the `repoURL`:

```bash
# Update all environments
find environments -name "application.yaml" -exec sed -i '' 's|https://github.ibm.com/jortiz/argocd-helm.git|https://github.ibm.com/jortiz/argocd-helm.git|g' {} \;

# Or update individually
vi environments/dev/application.yaml
vi environments/staging/application.yaml
vi environments/prod/application.yaml
```

### Change Target Branch

```yaml
# environments/dev/application.yaml
spec:
  source:
    targetRevision: develop  # Change to your dev branch

# environments/prod/application.yaml
spec:
  source:
    targetRevision: v1.0.0   # Use tagged releases for prod
```

### Enable/Disable Auto-Sync

```yaml
# Enable auto-sync (dev/staging)
spec:
  syncPolicy:
    automated:
      prune: true
      selfHeal: true

# Disable auto-sync (production)
spec:
  syncPolicy:
    # No automated section = manual sync required
    syncOptions:
      - CreateNamespace=true
```

## ApplicationSet vs Individual Applications

### Use ApplicationSet When:
- ✅ All environments have similar configuration
- ✅ You want to manage environments together
- ✅ You need to add/remove environments dynamically
- ✅ Configuration differences can be parameterized

### Use Individual Applications When:
- ✅ Environments have very different requirements
- ✅ You need different sync policies per environment
- ✅ You want independent lifecycle management
- ✅ Different teams manage different environments

## Common Operations

### View All Applications

```bash
oc get applications -n openshift-gitops
```

### Check Application Status

```bash
oc get application sample-app-dev -n openshift-gitops
oc describe application sample-app-dev -n openshift-gitops
```

### Manual Sync

```bash
# Sync specific environment
oc patch application sample-app-prod -n openshift-gitops \
  --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'

# Or use ArgoCD CLI
argocd app sync sample-app-prod
```

### View Sync History

```bash
argocd app history sample-app-prod
```

### Rollback

```bash
argocd app rollback sample-app-prod <revision-number>
```

## Troubleshooting

### Application Not Syncing

```bash
# Check application status
oc describe application sample-app-dev -n openshift-gitops

# Check sync status
oc get application sample-app-dev -n openshift-gitops -o jsonpath='{.status.sync.status}'

# View conditions
oc get application sample-app-dev -n openshift-gitops -o jsonpath='{.status.conditions}'
```

### Repository Access Issues

```bash
# Check repository connection
argocd repo list

# Add repository credentials (if private)
argocd repo add https://github.ibm.com/jortiz/argocd-helm.git \
  --username your-username \
  --password your-token
```

### Permission Issues

```bash
# Check ArgoCD service account permissions
oc get rolebinding -n sample-app-dev | grep argocd

# Grant additional permissions (if needed)
oc adm policy add-role-to-user admin \
  system:serviceaccount:openshift-gitops:openshift-gitops-argocd-application-controller \
  -n sample-app-dev
```

## Best Practices

1. **Use Git Tags for Production**: Reference specific versions in production
   ```yaml
   targetRevision: v1.0.0  # Not 'main'
   ```

2. **Require Manual Sync for Production**: Prevent automatic changes
   ```yaml
   syncPolicy:
     # No automated section
   ```

3. **Enable Auto-Sync for Lower Environments**: Fast feedback loop
   ```yaml
   syncPolicy:
     automated:
       prune: true
       selfHeal: true
   ```

4. **Use Separate Namespaces**: Isolate environments
   ```yaml
   destination:
     namespace: sample-app-dev  # Not shared
   ```

5. **Document Changes**: Use meaningful commit messages
   ```bash
   git commit -m "Enable auto-prune for dev environment"
   ```

6. **Test in Lower Environments First**: Dev → Staging → Production
   ```bash
   # Test in dev first
   oc apply -f environments/dev/application.yaml
   # Then staging
   oc apply -f environments/staging/application.yaml
   # Finally production (after validation)
   oc apply -f environments/prod/application.yaml
   ```

7. **Monitor Sync Status**: Watch for issues
   ```bash
   watch oc get applications -n openshift-gitops
   ```

8. **Use Health Checks**: Define proper health assessments
   ```yaml
   spec:
     ignoreDifferences:
       - group: apps
         kind: Deployment
         jsonPointers:
           - /spec/replicas  # Ignore HPA changes
   ```

## Migration from Legacy Structure

If you have old application files in the root `argocd/` directory:

1. **Keep old files temporarily** for backward compatibility
2. **Update references** to use new paths
3. **Test new structure** in dev environment
4. **Migrate one environment at a time**
5. **Remove old files** after successful migration

```bash
# Old (deprecated)
argocd/application.yaml
argocd/application-dev.yaml

# New (current)
argocd/environments/dev/application.yaml
argocd/environments/staging/application.yaml
argocd/environments/prod/application.yaml
```

## Additional Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ApplicationSet Documentation](https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/)
- [Best Practices Guide](../BEST_PRACTICES.md)
- [Main README](../README.md)