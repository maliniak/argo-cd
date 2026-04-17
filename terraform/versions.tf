terraform {
  required_version = ">= 1.6.0"

  # Uncomment after running: terraform apply (to create the bucket & table)
  # then run: terraform init -migrate-state
  #
  # backend "s3" {
  #   bucket         = "<your-tfstate-bucket-name>"   # var.tfstate_bucket_name
  #   key            = "eks-fargate/terraform.tfstate"
  #   region         = "eu-central-1"                 # var.aws_region
  #   encrypt        = true
  #   dynamodb_table = "<your-lock-table-name>"        # var.tfstate_lock_table_name
  # }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.28"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.15"
    }
  }
}
