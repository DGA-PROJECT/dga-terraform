terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "tfe_outputs" "jinsung" {
  organization = "DGA-PROJECT"
  workspace = "jinsung"
}
provider "kubernetes" {
  host                   = data.tfe_outputs.jinsung.values.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(data.tfe_outputs.jinsung.values.eks_cluster_certificate_authority_data)
  token                  = data.tfe_outputs.jinsung.values.token
}

provider "helm" {
  kubernetes {
    host                   = data.tfe_outputs.jinsung.values.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(data.tfe_outputs.jinsung.values.eks_cluster_certificate_authority_data)
    token                  = data.tfe_outputs.jinsung.values.token
  }
}