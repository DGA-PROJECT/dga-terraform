
# # #  EKS module

module "dga-eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "18.26.6"
  cluster_name    = "dga-cluster-test"
  cluster_version = "1.29"
  # k8s version

  cluster_security_group_id = var.dga-pri-sg-id
  # node_security_group_id = var.dga-pub-sg-id
  # security group 설정

  vpc_id          = var.dga-vpc-id
  # vpc id

  subnet_ids = [
    var.dga-pri-1-id,
    var.dga-pri-2-id
  ]
  # 클러스터의 subnet 설정

  eks_managed_node_groups = {
    dga_node_group = {
      min_size       = 2
      max_size       = 4
      desired_size   = 3
      instance_types = ["m6i.large"]
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }

  cluster_endpoint_private_access = true
  # cluster를 private sub에 만듬
}

# # # provider

data "aws_eks_cluster_auth" "this" {
  name = "dga-cluster-test"
}


provider "helm" {
  kubernetes {
    host                   = module.dga-eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.dga-eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "kubernetes" {
  host                   = module.dga-eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.dga-eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

# # #

locals {
  lb_controller_iam_role_name        = "dga-eks-aws-lb-ctrl1"
  lb_controller_service_account_name = "aws-load-balancer-controller"
}
# 재설정 변수 

module "lb_controller_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"

  create_role = true

  role_name        = local.lb_controller_iam_role_name
  role_path        = "/"
  role_description = "Used by AWS Load Balancer Controller for EKS"

  role_permissions_boundary_arn = ""

  provider_url = replace(module.dga-eks.cluster_oidc_issuer_url, "https://", "")
  oidc_fully_qualified_subjects = [
    "system:serviceaccount:kube-system:${local.lb_controller_service_account_name}"
  ]
  oidc_fully_qualified_audiences = [
    "sts.amazonaws.com"
  ]
}

data "http" "iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.5.4/docs/install/iam_policy.json"
}

resource "aws_iam_role_policy" "controller" {
  name_prefix = "AWSLoadBalancerControllerIAMPolicy"
  policy      = data.http.iam_policy.body
  role        = module.lb_controller_role.iam_role_name
}

resource "helm_release" "release" {
  name       = "aws-load-balancer-controller"
  chart      = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  namespace  = "kube-system"

  dynamic "set" {
    for_each = {
      "clusterName"                                               = "dga-cluster-test"
      "serviceAccount.create"                                     = "true"
      "serviceAccount.name"                                       = local.lb_controller_service_account_name
      "region"                                                    = "ap-northeast-2"
      "vpcId"                                                     = var.dga-vpc-id
      "image.repository"                                          = "602401143452.dkr.ecr.ap-northeast-2.amazonaws.com/amazon/aws-load-balancer-controller"
      "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn" = "arn:aws:iam::420615923610:role/dga-eks-aws-lb-ctrl1"
    }
    content {
      name  = set.key
      value = set.value
    }
  }
}

# # # namespace

resource "kubernetes_namespace" "board" {
  metadata {
    name = "board"
  }
}
resource "kubernetes_namespace" "user" {
  metadata {
    name = "users"
  }
}
resource "kubernetes_namespace" "leaderboard" {
  metadata {
    name = "leaderboard"
  }
}
resource "kubernetes_namespace" "myplan" {
  metadata {
    name = "myplan"
  }
}
resource "kubernetes_namespace" "search" {
  metadata {
    name = "search"
  }
}
resource "kubernetes_namespace" "admin" {
  metadata {
    name = "admin"
  }
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}


# # # ingress 배포

resource "kubernetes_ingress_v1" "alb" {
  metadata {
    name = "alb"
    annotations = {
      "alb.ingress.kubernetes.io/scheme"      = "internet-facing",
      "alb.ingress.kubernetes.io/target-type" = "ip",
    }
  }
  spec {
    ingress_class_name = "alb"
    rule {
      http {
        path {
          backend {
            service {
              name = "echo"
              port {
                number = 8080
              }
            }
          }
          path = "/*"
        }
      }
    }
  }
}