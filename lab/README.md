# Argo CD GitOps Lab

This lab adds three small services to the repository so you can practice the full GitOps loop on your EKS Fargate cluster:

- `backend-b`: inventory API
- `backend-a`: orders API that calls `backend-b`
- `frontend`: simple UI exposed through an ALB Ingress and calling `backend-a` on `/api`

The deployment flow is:

1. Push application code to GitHub.
2. A single GitHub Actions workflow builds changed services.
3. On pull requests it performs build-only validation.
4. On `main`, it pushes changed images to ECR and updates Helm values in Git.
5. Argo CD detects the manifest change and syncs the cluster.

## Repository Layout

```text
lab/
  apps/
    backend-a/
    backend-b/
    frontend/
  k8s/
    base/
      Chart.yaml
      values.yaml
      templates/
  argocd/
```

## Prerequisites

- The Terraform stack has been applied after these lab changes, so the `demo` Fargate profile and ECR repositories exist.
- Argo CD is already installed by the Terraform in this repository.
- The AWS Load Balancer Controller is healthy in the cluster.
- This repository is pushed to GitHub.

## 1. Apply the Terraform changes

From [terraform/main.tf](/Users/mmalinow/Documents/ideaProjects/mentoring/eks-fargate/terraform/main.tf) and [terraform/variables.tf](/Users/mmalinow/Documents/ideaProjects/mentoring/eks-fargate/terraform/variables.tf), Terraform now creates:

- the `demo` Fargate-backed namespace selector
- three ECR repositories under the `gitops-lab` prefix

Run:

```bash
cd terraform
terraform init
terraform apply
```

Fetch the repository URLs after apply:

```bash
terraform output gitops_lab_ecr_repository_urls
```

## 2. Integrate GitHub Actions with AWS

Use GitHub OIDC. Do not store long-lived AWS keys in GitHub.

### 2.1 Create an IAM policy for ECR push access

Create a policy similar to this, scoped to the three lab repositories:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeRepositories",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart"
      ],
      "Resource": [
        "arn:aws:ecr:eu-central-1:<account-id>:repository/gitops-lab/backend-a",
        "arn:aws:ecr:eu-central-1:<account-id>:repository/gitops-lab/backend-b",
        "arn:aws:ecr:eu-central-1:<account-id>:repository/gitops-lab/frontend"
      ]
    }
  ]
}
```

### 2.2 Create the GitHub OIDC identity provider

If the AWS account does not already have GitHub OIDC configured, create the provider once:

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### 2.3 Create an IAM role trusted by your repository

Trust policy template:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<account-id>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:<github-org>/<github-repo>:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

Attach the ECR push policy to that role.

### 2.4 Add the role ARN to GitHub

In the GitHub repository settings, add this secret:

- `AWS_GITHUB_ACTIONS_ROLE_ARN`

If you use a region other than `eu-central-1`, update [lab-release.yaml](/Users/mmalinow/Documents/ideaProjects/mentoring/eks-fargate/.github/workflows/lab-release.yaml) before pushing.

## 3. Point Argo CD to your Git repository

Replace the placeholder `repoURL` values in these files with your actual repository URL:

- [lab/argocd/root-application.yaml](/Users/mmalinow/Documents/ideaProjects/mentoring/eks-fargate/lab/argocd/root-application.yaml)
- [lab/argocd/apps/demo-lab.yaml](/Users/mmalinow/Documents/ideaProjects/mentoring/eks-fargate/lab/argocd/apps/demo-lab.yaml)

Then apply the Argo CD resources:

```bash
kubectl apply -f lab/argocd/project.yaml
kubectl apply -f lab/argocd/root-application.yaml
```

## 4. Pipeline

The repository now has a single service-image workflow:

- [lab-release.yaml](/Users/mmalinow/Documents/ideaProjects/mentoring/eks-fargate/.github/workflows/lab-release.yaml):
  - on pull requests: builds only the changed services
  - on pushes to `main`: builds and pushes changed services to ECR, then updates Helm values in [values.yaml](/Users/mmalinow/Documents/ideaProjects/mentoring/eks-fargate/lab/k8s/base/values.yaml)

## 5. Build the initial images

The manifests start with placeholder image names. Push this repo to GitHub and run the workflow once:

```bash
gh workflow run lab-release
```

After that first run:

- images are pushed to ECR
- `lab/k8s/base/values.yaml` contains the real ECR image URLs and tags
- Argo CD can sync the workloads successfully

## 6. Test the lab

Find the frontend ALB hostname:

```bash
kubectl -n demo get ingress frontend
```

Open the address shown in `STATUS.loadBalancer.ingress[0].hostname`.

The browser calls the frontend, the frontend calls `/api/orders/<id>`, `backend-a` calls `backend-b`, and the JSON response comes back through the chain.

## 7. Practice the GitOps flow

Good first exercises:

1. Change product prices in [lab/apps/backend-b/app/main.py](/Users/mmalinow/Documents/ideaProjects/mentoring/eks-fargate/lab/apps/backend-b/app/main.py).
2. Change the order list in [lab/apps/backend-a/app/main.py](/Users/mmalinow/Documents/ideaProjects/mentoring/eks-fargate/lab/apps/backend-a/app/main.py).
3. Change the frontend styling in [lab/apps/frontend/app/main.py](/Users/mmalinow/Documents/ideaProjects/mentoring/eks-fargate/lab/apps/frontend/app/main.py).

For each change:

1. Commit and push to `main`.
2. Let GitHub Actions build, push, and commit the new image tags.
3. Watch Argo CD detect drift and sync.
4. Refresh the frontend and confirm the rollout.