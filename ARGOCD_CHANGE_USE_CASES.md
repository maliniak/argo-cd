# Argo CD In This Project: How It Works and How To Observe It

This guide explains the GitOps flow between the `argo-cd` and `lab` repositories and gives practical use-cases you can run to see reconciliation in action.

## 1) How Argo CD Works Here

There are two repositories with clear responsibilities:

- `argo-cd` repository:
  - provisions infrastructure with Terraform (`terraform/`)
  - installs Argo CD (`terraform/argocd.tf`)
  - bootstraps Argo applications (`argocd/project.yaml`, `argocd/root-application.yaml`, `argocd/apps/*.yaml`)
- `lab` repository:
  - contains app source code (`apps/`)
  - contains Helm chart + environment values (`k8s/base/`)
  - contains CI workflow that builds images and updates values files (`.github/workflows/lab-release.yaml`)

Argo CD hierarchy in this setup:

1. Root app (`argocd/root-application.yaml`) watches `argo-cd/argocd/apps`.
2. Child app `demo-lab-dev` watches `lab/k8s/base` with `values-dev.yaml` and auto-sync enabled.
3. Child app `demo-lab-prod` watches `lab/k8s/base` with `values-prod.yaml` and no automated sync block (promotion oriented).

Result:

- changes to app manifests/values in `lab` become desired state
- Argo CD detects drift and reconciles cluster resources back to desired state
- dev and prod are separated by values files and sync policy

## 2) Why This Is Beneficial

Key benefits of this GitOps model:

- **Auditability:** every infra/app change is captured in Git history.
- **Reproducibility:** cluster state is declarative and can be recreated from versioned manifests.
- **Safer promotion:** dev can move fast while prod promotion remains explicit and controlled.
- **Reduced manual ops:** Argo CD continuously converges the cluster, reducing imperative `kubectl` changes.
- **Clear ownership split:** platform lifecycle in `argo-cd`, application lifecycle in `lab`.

## 3) Before Running Use-Cases

Ensure these are available:

- Kubernetes access configured for the EKS cluster.
- Argo CD bootstrap already applied.
- `lab` and `argo-cd` repositories pushed to remotes used by Argo CD.

Useful checks:

```bash
kubectl get ns | rg "argocd|demo-dev|demo-prod"
kubectl -n argocd get applications
```

Optional UI access:

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:80
```

Then open [http://localhost:8080](http://localhost:8080).

## 4) Use-Cases: Trigger Changes and Verify

### Use-case A: Frontend-only change in dev (fastest demo)

Goal: show automatic `demo-lab-dev` reconciliation.

Trigger:

1. In `lab/apps/frontend/app/main.py`, change visible UI text (for example page title).
2. Commit and push to `main`.

Expected pipeline behavior:

- `lab-release` (`release-dev`) builds only `frontend`.
- Updates `k8s/base/values-dev.yaml` with the new image tag.
- Commits values change.
- Argo CD marks `demo-lab-dev` OutOfSync, then Synced after rollout.

Verify:

```bash
kubectl -n argocd get app demo-lab-dev
kubectl -n demo-dev rollout status deploy/frontend
kubectl -n demo-dev get pods
```

If ingress is configured:

```bash
ALB=$(kubectl -n demo-dev get ingress frontend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -H "Host: dev-app.malinka-labs-argo.net" "http://$ALB/"
```

### Use-case B: Multi-service functional change in dev

Goal: show one commit triggering two app rollouts and end-to-end behavior change.

Trigger:

1. In `lab/apps/backend-orders/app/main.py`, add a new order id in the in-memory order list.
2. In `lab/apps/frontend/app/main.py`, add small UI text so change is visible.
3. Commit and push both files to `main`.

Expected behavior:

- CI detects both changed services and builds two images.
- CI updates two tags in `values-dev.yaml` (same commit SHA).
- Argo CD reconciles both `backend-orders` and `frontend` Deployments in `demo-dev`.

Verify:

```bash
kubectl -n demo-dev rollout status deploy/backend-orders
kubectl -n demo-dev rollout status deploy/frontend
kubectl -n demo-dev get pods
```

Functional verification through ingress:

```bash
curl -H "Host: dev-app.malinka-labs-argo.net" "http://$ALB/api/orders/103"
```

### Use-case C: Promote tested tag to prod

Goal: demonstrate controlled promotion without rebuilding images.

Trigger:

1. Take a tested tag from `values-dev.yaml`.
2. Run manual workflow `promote-prod` in `lab` repository.
3. Workflow updates `k8s/base/values-prod.yaml`.

Example:

```bash
gh workflow run lab-release \
  -f operation=promote-prod \
  -f promote_tag=<tested-dev-sha> \
  -f promote_services=backend-orders,backend-products,frontend
```

Expected behavior:

- no image build occurs
- only prod values are updated
- Argo CD syncs `demo-lab-prod`

Verify:

```bash
kubectl -n argocd get app demo-lab-prod
kubectl -n demo-prod rollout status deploy/frontend
kubectl -n demo-prod rollout status deploy/backend-orders
kubectl -n demo-prod rollout status deploy/backend-products
```

## 5) What To Watch During Sync

During any use-case, these signals prove GitOps is working:

- Argo app state changes: `Synced -> OutOfSync -> Synced`
- deployment rollout updates pods in target namespace
- running pod images match tags in the values file

Quick image check:

```bash
kubectl -n demo-dev get pod -l app.kubernetes.io/name=frontend -o jsonpath='{.items[0].spec.containers[0].image}{"\n"}'
kubectl -n demo-prod get pod -l app.kubernetes.io/name=frontend -o jsonpath='{.items[0].spec.containers[0].image}{"\n"}'
```
