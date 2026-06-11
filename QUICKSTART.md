# Quick Start Guide

This guide will help you quickly deploy the sample application using Red Hat OpenShift GitOps (ArgoCD).

## Prerequisites Checklist

- [ ] OpenShift cluster access
- [ ] `oc` CLI installed
- [ ] Git repository created (GitHub, GitLab, etc.)
- [ ] This code pushed to your Git repository

## 5-Minute Setup

### Step 1: Install OpenShift GitOps Operator (2 minutes)

```bash
# Install the operator
oc apply -f - <<EOF
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

# Wait for installation (check every 10 seconds)
watch oc get pods -n openshift-gitops
```

Press `Ctrl+C` when you see all pods running.

### Step 2: Get ArgoCD Credentials (30 seconds)

```bash
# Get the ArgoCD URL
echo "ArgoCD URL: https://$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}')"

# Get the admin password
echo "Password: $(oc extract secret/openshift-gitops-cluster -n openshift-gitops --to=- --keys=admin.password 2>/dev/null)"
```

### Step 3: Update Application Manifests (1 minute)

**Option A: Deploy Single Environment (Dev)**

Edit `argocd/environments/dev/application.yaml`:

```yaml
spec:
  source:
    repoURL: https://github.com/YOUR-USERNAME/YOUR-REPO.git  # ← Change this
    targetRevision: develop  # ← Your dev branch
```

**Option B: Deploy All Environments (Recommended)**

Edit `argocd/applicationset.yaml`:

```yaml
spec:
  template:
    spec:
      source:
        repoURL: https://github.com/YOUR-USERNAME/YOUR-REPO.git  # ← Change this
```

### Step 4: Deploy Application (1 minute)

**Option A: Deploy to Dev Only**

```bash
# Push your changes to Git
git add .
git commit -m "Configure ArgoCD application"
git push

# Deploy to dev environment
oc apply -f argocd/environments/dev/application.yaml

# Watch the deployment
oc get application sample-app-dev -n openshift-gitops -w
```

**Option B: Deploy All Environments**

```bash
# Push your changes to Git
git add .
git commit -m "Configure ArgoCD applications"
git push

# Deploy all environments using ApplicationSet
oc apply -f argocd/applicationset.yaml

# Watch all deployments
oc get application -n openshift-gitops -w
```

Press `Ctrl+C` when status shows "Synced" and "Healthy".

### Step 5: Verify Deployment (30 seconds)

```bash
# Check application resources
oc get all -n sample-app

# Check ConfigMaps
oc get configmap -n sample-app

# View application logs
oc logs -l app.kubernetes.io/name=sample-app -n sample-app
```

## What Was Created?

```
sample-app namespace
├── Deployment (2 replicas of nginx)
├── Service (ClusterIP on port 80)
├── ConfigMap: app-config
│   ├── APP_NAME=sample-application
│   ├── APP_ENV=production
│   └── LOG_LEVEL=info
└── ConfigMap: database-config
    ├── DB_HOST=postgres.default.svc.cluster.local
    ├── DB_PORT=5432
    └── DB_NAME=appdb
```

## Access ArgoCD UI

1. Open the ArgoCD URL from Step 2
2. Login with username: `admin` and the password from Step 2
3. You should see your `sample-app` application

## Common Commands

```bash
# View application status
oc get application sample-app -n openshift-gitops

# Describe application (detailed info)
oc describe application sample-app -n openshift-gitops

# Force sync
oc patch application sample-app -n openshift-gitops --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'

# Delete application
oc delete application sample-app -n openshift-gitops
```

## Testing Changes

1. Modify `values.yaml` (e.g., change `replicaCount: 3`)
2. Commit and push to Git
3. ArgoCD will automatically sync (if automated sync is enabled)
4. Or manually sync from UI or CLI

## Deploy to Development Environment

```bash
# Deploy dev version
oc apply -f argocd/application-dev.yaml

# Check dev deployment
oc get all -n sample-app-dev
```

## Troubleshooting

### Application Not Syncing

```bash
# Check application events
oc describe application sample-app -n openshift-gitops

# Check ArgoCD logs
oc logs -n openshift-gitops -l app.kubernetes.io/name=openshift-gitops-application-controller
```

### Permission Issues

```bash
# Grant ArgoCD admin access (for testing only)
oc adm policy add-cluster-role-to-user cluster-admin -z openshift-gitops-argocd-application-controller -n openshift-gitops
```

### Repository Access Issues

If using private repository:
1. Go to ArgoCD UI → Settings → Repositories
2. Click "Connect Repo"
3. Add your repository credentials

## Next Steps

- [ ] Customize the Helm chart for your application
- [ ] Add more environments (staging, production)
- [ ] Configure webhooks for automatic sync
- [ ] Set up notifications (Slack, email)
- [ ] Integrate with CI/CD pipeline
- [ ] Add Prometheus monitoring
- [ ] Configure RBAC for team access

## Need Help?

- Check the main [README.md](README.md) for detailed documentation
- Review [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- Check [OpenShift GitOps Docs](https://docs.openshift.com/container-platform/latest/cicd/gitops/understanding-openshift-gitops.html)