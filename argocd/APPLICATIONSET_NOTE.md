# ApplicationSet Note

## Important Limitation

The ApplicationSet in this project creates applications for all three environments (dev, staging, prod) with the **same sync policy**.

### Current Behavior

All environments created by the ApplicationSet will have:
- ✅ `CreateNamespace=true` (automatic namespace creation)
- ✅ Retry policy configured
- ❌ **No automated sync** (manual sync required for all)

### Why No Conditional Auto-Sync?

ApplicationSet does not support conditional logic for the `automated` sync policy based on parameters. The Go template syntax in ApplicationSet is limited compared to Helm templates.

## Recommended Approach

### Option 1: Use Individual Applications (Recommended)

For production environments where you need different sync policies, use individual Application manifests:

```bash
# Deploy with different sync policies per environment
oc apply -f argocd/environments/dev/application.yaml      # Auto-sync enabled
oc apply -f argocd/environments/staging/application.yaml  # Auto-sync enabled
oc apply -f argocd/environments/prod/application.yaml     # Manual sync (no auto-sync)
```

**Benefits**:
- ✅ Different sync policies per environment
- ✅ Production safety (manual sync for prod)
- ✅ Auto-sync for dev/staging (fast feedback)
- ✅ Full control over each environment

### Option 2: Use ApplicationSet for Non-Production

Use ApplicationSet only for dev/staging, and individual Application for production:

```bash
# Create a separate ApplicationSet for non-prod
# argocd/applicationset-nonprod.yaml (only dev and staging)

# Use individual Application for production
oc apply -f argocd/environments/prod/application.yaml
```

### Option 3: Accept Manual Sync for All

If you're okay with manual sync for all environments:

```bash
# Deploy all with ApplicationSet
oc apply -f argocd/applicationset.yaml

# Manually sync each environment when needed
argocd app sync sample-app-dev
argocd app sync sample-app-staging
argocd app sync sample-app-prod
```

## Comparison

| Approach | Dev Auto-Sync | Staging Auto-Sync | Prod Auto-Sync | Complexity |
|----------|---------------|-------------------|----------------|------------|
| Individual Applications | ✅ Yes | ✅ Yes | ❌ No (Manual) | Low |
| ApplicationSet | ❌ No | ❌ No | ❌ No | Very Low |
| Hybrid (Set + Individual) | ✅ Yes | ✅ Yes | ❌ No (Manual) | Medium |

## Our Recommendation

**Use Individual Applications** (Option 1) because:
1. ✅ Production safety with manual sync
2. ✅ Fast feedback in dev/staging with auto-sync
3. ✅ Simple to understand and maintain
4. ✅ Full control over each environment
5. ✅ Easy to customize per environment

## Example: Deploy Individual Applications

```bash
# Deploy all environments with proper sync policies
oc apply -f argocd/environments/dev/application.yaml
oc apply -f argocd/environments/staging/application.yaml
oc apply -f argocd/environments/prod/application.yaml

# Verify
oc get applications -n openshift-gitops

# Check sync policies
oc get application sample-app-dev -n openshift-gitops -o jsonpath='{.spec.syncPolicy.automated}'
# Output: {"prune":true,"selfHeal":true} (auto-sync enabled)

oc get application sample-app-prod -n openshift-gitops -o jsonpath='{.spec.syncPolicy.automated}'
# Output: (empty - manual sync)
```

## When to Use ApplicationSet

ApplicationSet is great for:
- ✅ Creating many similar applications
- ✅ Dynamic environment creation
- ✅ Non-production environments only
- ✅ When all environments can have the same sync policy

ApplicationSet is **not ideal** for:
- ❌ Different sync policies per environment
- ❌ Production environments requiring manual approval
- ❌ Complex per-environment customization

## Summary

For this project, we recommend:
1. **Use individual Applications** for full control
2. Keep the ApplicationSet as an alternative option
3. Document the trade-offs clearly

The individual Application files in `argocd/environments/*/application.yaml` are already configured with the correct sync policies for each environment.