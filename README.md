# Sample Helm Chart with Red Hat OpenShift GitOps (ArgoCD) Integration

This repository demonstrates how to deploy a Helm chart using Red Hat OpenShift GitOps (ArgoCD) following enterprise GitOps best practices. The chart creates basic Kubernetes resources including ConfigMaps, Deployments, and Services.

## Prerequisites

- OpenShift cluster with Red Hat OpenShift GitOps operator installed
- `oc` CLI tool installed and configured
- `helm` CLI tool installed (optional, for local testing)
- Git repository to host this chart

## Project Structure

```
argocd-helm/
├── Chart.yaml                          # Helm chart metadata
├── values.yaml                         # Base values (shared configuration)
├── templates/                          # Helm templates
│   ├── _helpers.tpl                   # Template helper functions
│   ├── configmaps.yaml                # ConfigMap template
│   ├── deployment.yaml                # Deployment template
│   └── service.yaml                   # Service template
├── environments/                       # Environment-specific Helm values
│   ├── README.md                      # Environment documentation
│   ├── dev/
│   │   └── values.yaml               # Development configuration
│   ├── staging/
│   │   └── values.yaml               # Staging configuration
│   └── prod/
│       └── values.yaml               # Production configuration
├── argocd/                            # ArgoCD manifests (separate from Helm)
│   ├── README.md                      # ArgoCD documentation
│   ├── APPLICATIONSET_NOTE.md         # ApplicationSet limitations
│   ├── applicationset.yaml            # ApplicationSet for all environments
│   └── environments/
│       ├── dev/
│       │   └── application.yaml      # Dev deployment (auto-sync enabled)
│       ├── staging/
│       │   └── application.yaml      # Staging deployment (auto-sync enabled)
│       └── prod/
│           └── application.yaml      # Prod deployment (manual sync)
├── Makefile                           # Common operations
├── BEST_PRACTICES.md                  # GitOps best practices guide
├── NAMESPACE_GUIDE.md                 # Namespace management guide
├── STRUCTURE.md                       # Project structure overview
├── QUICKSTART.md                      # Quick start guide
├── TESTING.md                         # Testing guide
└── README.md                          # This file
```

## Why This Structure?

### Separation of Concerns

This project follows GitOps best practices by separating:

**Helm Values** (`environments/*/values.yaml`):
- Application configuration
- Managed by application teams
- Changes frequently with application updates

**ArgoCD Applications** (`argocd/environments/*/application.yaml`):
- Deployment strategy and sync policies
- Managed by platform/DevOps teams
- Changes infrequently

See [BEST_PRACTICES.md](BEST_PRACTICES.md) for detailed explanation.

## Helm Chart Components

### ConfigMaps
The chart creates two ConfigMaps:
- **app-config**: Application configuration (name, environment, log level)
- **database-config**: Database connection settings

### Deployment
- Deploys nginx as a sample application
- Configurable replica count per environment
- Injects ConfigMaps as environment variables
- Includes liveness and readiness probes
- Resource limits and requests

### Service
- ClusterIP service exposing port 80
- Routes traffic to the deployment pods

## Environment Configurations

| Environment | Namespace | Replicas | Image Tag | Log Level | Auto-Sync | Branch |
|-------------|-----------|----------|-----------|-----------|-----------|--------|
| Development | `sample-app-dev` | 1 | `latest` | `debug` | ✅ Yes | `develop` |
| Staging | `sample-app-staging` | 2 | `1.21` | `info` | ✅ Yes | `main` |
| Production | `sample-app-prod` | 3 | `1.21` | `info` | ❌ No (Manual) | `main` |

## Namespace Management

**Namespaces are created automatically!** Each ArgoCD Application is configured with:

```yaml
spec:
  destination:
    namespace: sample-app-dev  # Target namespace
  syncPolicy:
    syncOptions:
      - CreateNamespace=true   # Auto-create if doesn't exist
```

No manual namespace creation is needed. See [NAMESPACE_GUIDE.md](NAMESPACE_GUIDE.md) for details.

## Installation Methods

### Method 1: Using ArgoCD Individual Applications (Recommended)

This method provides the best control with different sync policies per environment.

#### Step 1: Install Red Hat OpenShift GitOps Operator

```bash
# Create the operator subscription
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-gitops-operator
  namespace: openshift-operators
spec:
  channel: latest
  name: openshift-gitops-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
```

Wait for the operator to be installed:
```bash
oc get pods -n openshift-gitops
```

#### Step 2: Access ArgoCD UI

Get the ArgoCD route:
```bash
oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}'
```

Get the admin password:
```bash
oc extract secret/openshift-gitops-cluster -n openshift-gitops --to=-
```

#### Step 3: Update ArgoCD Application Manifests

Edit the application files in the `argocd/environments/` directory and update the `repoURL`:

```bash
# Update all environments
find argocd/environments -name "application.yaml" -exec sed -i '' 's|https://github.ibm.com/jortiz/argocd-helm.git|https://github.ibm.com/jortiz/argocd-helm.git|g' {} \;

# Or update individually
vi argocd/environments/dev/application.yaml
vi argocd/environments/staging/application.yaml
vi argocd/environments/prod/application.yaml
```

#### Step 4: Deploy Applications

**Option A: Deploy Individual Environments**

```bash
# Push your changes to Git first
git add .
git commit -m "Configure ArgoCD applications"
git push

# Deploy to development (auto-sync enabled)
oc apply -f argocd/environments/dev/application.yaml

# Deploy to staging (auto-sync enabled)
oc apply -f argocd/environments/staging/application.yaml

# Deploy to production (manual sync required)
oc apply -f argocd/environments/prod/application.yaml
```

**Option B: Deploy All Environments at Once**

```bash
# Update ApplicationSet with your repo URL
vi argocd/applicationset.yaml

# Deploy all environments
oc apply -f argocd/applicationset.yaml
```

**Note**: ApplicationSet creates all applications with manual sync. For auto-sync in dev/staging, use individual applications (Option A).

#### Step 5: Monitor Deployment

```bash
# Watch ArgoCD sync the applications
oc get application -n openshift-gitops

# Check specific environment status
oc describe application sample-app-dev -n openshift-gitops
oc describe application sample-app-staging -n openshift-gitops
oc describe application sample-app-prod -n openshift-gitops

# View deployed resources in each environment
oc get all -n sample-app-dev
oc get all -n sample-app-staging
oc get all -n sample-app-prod

# Verify namespaces were created
oc get namespaces | grep sample-app
```

#### Step 6: Sync Production (Manual)

For production, you must manually trigger sync:

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

### Method 2: Using Helm CLI (For Testing)

```bash
# Install the chart
helm install sample-app . -n sample-app --create-namespace

# Install with custom values
helm install sample-app . -n sample-app-dev --create-namespace -f environments/dev/values.yaml

# Upgrade the release
helm upgrade sample-app . -n sample-app

# Uninstall
helm uninstall sample-app -n sample-app
```

## ArgoCD Configuration Explained

### Individual Application Structure

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sample-app-dev
  namespace: openshift-gitops
spec:
  project: default
  
  source:
    repoURL: https://github.ibm.com/jortiz/argocd-helm.git
    targetRevision: develop
    path: .
    
    helm:
      valueFiles:
        - environments/dev/values.yaml  # Environment-specific values
  
  destination:
    server: https://kubernetes.default.svc
    namespace: sample-app-dev           # Target namespace
  
  syncPolicy:
    automated:                          # Auto-sync for dev
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true            # Auto-create namespace
```

### Key ArgoCD Features

#### Automated Sync (Dev/Staging)
```yaml
syncPolicy:
  automated:
    prune: true      # Delete resources not in Git
    selfHeal: true   # Auto-sync on drift
```

#### Manual Sync (Production)
```yaml
syncPolicy:
  # No automated section = manual sync required
  syncOptions:
    - CreateNamespace=true
```

#### Sync Options
```yaml
syncOptions:
  - CreateNamespace=true  # Auto-create namespace
  - PruneLast=true        # Delete resources last
```

#### Retry Policy
```yaml
retry:
  limit: 5
  backoff:
    duration: 5s
    factor: 2
    maxDuration: 3m
```

## Deployment Workflows

### Development Workflow
1. Developer pushes changes to `develop` branch
2. ArgoCD automatically syncs to `sample-app-dev` namespace
3. Changes are immediately visible for testing

### Staging Workflow
1. Merge `develop` to `main` branch
2. ArgoCD automatically syncs to `sample-app-staging` namespace
3. Run integration tests and QA

### Production Workflow
1. Tag a release in `main` branch
2. Update production Application to use the tag
3. **Manually** review and approve sync in ArgoCD
4. ArgoCD deploys to `sample-app-prod` namespace

## Customization

### Modify Environment Values

Edit the values file for the specific environment:

```bash
# Edit development configuration
vi environments/dev/values.yaml

# Commit and push
git add environments/dev/values.yaml
git commit -m "Update dev replica count"
git push

# ArgoCD will automatically sync (if auto-sync enabled)
```

### Add New Environment

1. Create values file:
```bash
mkdir -p environments/qa
cp environments/staging/values.yaml environments/qa/values.yaml
# Edit as needed
```

2. Create ArgoCD application:
```bash
mkdir -p argocd/environments/qa
cp argocd/environments/staging/application.yaml argocd/environments/qa/application.yaml
# Update name, namespace, and values file path
```

3. Deploy:
```bash
oc apply -f argocd/environments/qa/application.yaml
```

## Troubleshooting

### Check ArgoCD Application Status
```bash
oc get application sample-app-dev -n openshift-gitops
oc describe application sample-app-dev -n openshift-gitops
```

### View Sync Status
```bash
# Using ArgoCD CLI
argocd app get sample-app-dev

# View sync history
argocd app history sample-app-dev
```

### Manual Sync
```bash
# Force sync
argocd app sync sample-app-dev

# Sync with prune
argocd app sync sample-app-dev --prune
```

### Check Deployed Resources
```bash
oc get all -n sample-app-dev
oc get configmap -n sample-app-dev
oc logs deployment/sample-app-dev -n sample-app-dev
```

### Common Issues

1. **Application not syncing**: Check repository URL and credentials
2. **Namespace not created**: Ensure `CreateNamespace=true` in syncOptions
3. **Permission errors**: Verify ArgoCD has proper RBAC permissions
4. **YAML syntax errors**: Validate with `python3 -c "import yaml; yaml.safe_load(open('file.yaml'))"`

## Using the Makefile

The project includes a Makefile for common operations:

```bash
# View all available commands
make help

# Lint the Helm chart
make lint

# Test template rendering
make template-dev
make template-staging
make template-prod

# Deploy ArgoCD applications
make deploy-argocd-dev
make deploy-argocd-staging
make deploy-argocd-prod
make deploy-argocd-all

# Verify the chart
make verify

# View deployment status
make status
```

## Best Practices

1. **Use Git as Single Source of Truth**: All changes should go through Git
2. **Separate Concerns**: Keep Helm values separate from ArgoCD manifests
3. **Environment-Specific Values**: Use separate values files for each environment
4. **Automated Sync for Lower Environments**: Enable for dev/staging
5. **Manual Sync for Production**: Require manual approval for production
6. **Use Separate Namespaces**: Isolate environments
7. **Health Checks**: Define proper liveness and readiness probes
8. **Resource Limits**: Always set resource requests and limits
9. **Secrets Management**: Use sealed-secrets or external secret operators
10. **Monitoring**: Integrate with Prometheus and Grafana

## Documentation

- **[BEST_PRACTICES.md](BEST_PRACTICES.md)**: GitOps best practices and patterns
- **[NAMESPACE_GUIDE.md](NAMESPACE_GUIDE.md)**: Complete namespace management guide
- **[STRUCTURE.md](STRUCTURE.md)**: Detailed project structure overview
- **[QUICKSTART.md](QUICKSTART.md)**: 5-minute quick start guide
- **[TESTING.md](TESTING.md)**: Testing guide with examples
- **[argocd/README.md](argocd/README.md)**: ArgoCD-specific documentation
- **[argocd/APPLICATIONSET_NOTE.md](argocd/APPLICATIONSET_NOTE.md)**: ApplicationSet limitations
- **[environments/README.md](environments/README.md)**: Environment configuration guide

## Additional Resources

- [Red Hat OpenShift GitOps Documentation](https://docs.openshift.com/container-platform/latest/cicd/gitops/understanding-openshift-gitops.html)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Helm Documentation](https://helm.sh/docs/)
- [ApplicationSet Documentation](https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/)

## License

MIT License

## Contributing

Contributions are welcome! Please read the documentation and follow the established patterns.