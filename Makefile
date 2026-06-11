.PHONY: help install uninstall upgrade test lint template deploy-argocd clean

# Variables
CHART_NAME := sample-app
NAMESPACE := sample-app
RELEASE_NAME := sample-app

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

install: ## Install the Helm chart
	helm install $(RELEASE_NAME) . -n $(NAMESPACE) --create-namespace

install-dev: ## Install with dev values
	helm install $(RELEASE_NAME)-dev . -n $(NAMESPACE)-dev --create-namespace -f environments/dev/values.yaml

install-staging: ## Install with staging values
	helm install $(RELEASE_NAME)-staging . -n $(NAMESPACE)-staging --create-namespace -f environments/staging/values.yaml

install-prod: ## Install with prod values
	helm install $(RELEASE_NAME)-prod . -n $(NAMESPACE)-prod --create-namespace -f environments/prod/values.yaml

uninstall: ## Uninstall the Helm chart
	helm uninstall $(RELEASE_NAME) -n $(NAMESPACE)

upgrade: ## Upgrade the Helm chart
	helm upgrade $(RELEASE_NAME) . -n $(NAMESPACE)

upgrade-dev: ## Upgrade with dev values
	helm upgrade $(RELEASE_NAME)-dev . -n $(NAMESPACE)-dev -f environments/dev/values.yaml

upgrade-staging: ## Upgrade with staging values
	helm upgrade $(RELEASE_NAME)-staging . -n $(NAMESPACE)-staging -f environments/staging/values.yaml

upgrade-prod: ## Upgrade with prod values
	helm upgrade $(RELEASE_NAME)-prod . -n $(NAMESPACE)-prod -f environments/prod/values.yaml

test: ## Run Helm tests
	helm test $(RELEASE_NAME) -n $(NAMESPACE)

lint: ## Lint the Helm chart
	helm lint .

template: ## Generate Kubernetes manifests
	helm template $(RELEASE_NAME) . -n $(NAMESPACE)

template-dev: ## Generate manifests with dev values
	helm template $(RELEASE_NAME)-dev . -n $(NAMESPACE)-dev -f environments/dev/values.yaml

template-staging: ## Generate manifests with staging values
	helm template $(RELEASE_NAME)-staging . -n $(NAMESPACE)-staging -f environments/staging/values.yaml

template-prod: ## Generate manifests with prod values
	helm template $(RELEASE_NAME)-prod . -n $(NAMESPACE)-prod -f environments/prod/values.yaml

deploy-argocd-dev: ## Deploy ArgoCD Application for dev
	oc apply -f argocd/environments/dev/application.yaml

deploy-argocd-staging: ## Deploy ArgoCD Application for staging
	oc apply -f argocd/environments/staging/application.yaml

deploy-argocd-prod: ## Deploy ArgoCD Application for prod
	oc apply -f argocd/environments/prod/application.yaml

deploy-argocd-all: ## Deploy ArgoCD ApplicationSet for all environments
	oc apply -f argocd/applicationset.yaml

delete-argocd-dev: ## Delete ArgoCD Application for dev
	oc delete -f argocd/environments/dev/application.yaml

delete-argocd-staging: ## Delete ArgoCD Application for staging
	oc delete -f argocd/environments/staging/application.yaml

delete-argocd-prod: ## Delete ArgoCD Application for prod
	oc delete -f argocd/environments/prod/application.yaml

delete-argocd-all: ## Delete ArgoCD ApplicationSet
	oc delete -f argocd/applicationset.yaml

status: ## Show deployment status
	@echo "=== Helm Releases ==="
	@helm list -A | grep $(CHART_NAME) || echo "No releases found"
	@echo ""
	@echo "=== ArgoCD Applications ==="
	@oc get application -n openshift-gitops | grep $(CHART_NAME) || echo "No applications found"
	@echo ""
	@echo "=== Kubernetes Resources ==="
	@oc get all -n $(NAMESPACE) 2>/dev/null || echo "Namespace $(NAMESPACE) not found"

logs: ## Show application logs
	oc logs -l app.kubernetes.io/name=$(CHART_NAME) -n $(NAMESPACE) --tail=50 -f

describe: ## Describe ArgoCD application
	oc describe application $(CHART_NAME) -n openshift-gitops

sync: ## Manually sync ArgoCD application
	@echo "Triggering manual sync..."
	@oc patch application $(CHART_NAME) -n openshift-gitops --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'

clean: ## Clean up all resources
	-helm uninstall $(RELEASE_NAME) -n $(NAMESPACE)
	-helm uninstall $(RELEASE_NAME)-dev -n $(NAMESPACE)-dev
	-helm uninstall $(RELEASE_NAME)-staging -n $(NAMESPACE)-staging
	-oc delete -f argocd/application.yaml
	-oc delete -f argocd/application-dev.yaml
	-oc delete -f argocd/applicationset.yaml
	-oc delete namespace $(NAMESPACE)
	-oc delete namespace $(NAMESPACE)-dev
	-oc delete namespace $(NAMESPACE)-staging

package: ## Package the Helm chart
	helm package .

verify: ## Verify the Helm chart
	@echo "Linting chart..."
	@helm lint .
	@echo ""
	@echo "Checking templates..."
	@helm template $(RELEASE_NAME) . > /dev/null && echo "✓ Templates are valid"
	@echo ""
	@echo "Checking environment values files..."
	@helm template $(RELEASE_NAME) . -f environments/dev/values.yaml > /dev/null && echo "✓ environments/dev/values.yaml is valid"
	@helm template $(RELEASE_NAME) . -f environments/staging/values.yaml > /dev/null && echo "✓ environments/staging/values.yaml is valid"
	@helm template $(RELEASE_NAME) . -f environments/prod/values.yaml > /dev/null && echo "✓ environments/prod/values.yaml is valid"

# Made with Bob
