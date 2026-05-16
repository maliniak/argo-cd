# Import existing bootstrap resources into Terraform state.
# Keep this file while onboarding an already bootstrapped account,
# then remove it after a successful `terraform apply` if you prefer.

import {
  to = aws_s3_bucket.tfstate
  id = var.tfstate_bucket_name
}

import {
  to = aws_dynamodb_table.tfstate_lock
  id = var.tfstate_lock_table_name
}

import {
  to = aws_ecr_repository.gitops_lab["backend-orders"]
  id = "gitops-lab/backend-orders"
}

import {
  to = aws_ecr_repository.gitops_lab["backend-products"]
  id = "gitops-lab/backend-products"
}

import {
  to = aws_ecr_repository.gitops_lab["frontend"]
  id = "gitops-lab/frontend"
}
