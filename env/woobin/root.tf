# 타 워크스페이스에서 값을 받아옴
# VPC module
module "dga-vpc" {
  source = "./module/vpc"
  vpc_cidr = var.vpc_cidr
}

# Security Group
module "dga-sg" {
  source = "./module/sg"
  vpc-id = module.dga-vpc.dga-vpc-id
}

# ELB
module "dga-elb" {
  source = "./module/elb"
  vpc-id = module.dga-vpc.dga-vpc-id
  nlb-subs = [module.dga-vpc.dga-pub-1-id, module.dga-vpc.dga-pub-2-id]
  nlb-sg = module.dga-sg.dga-pub-sg-id
  # alb-arn = var.alb-arn
  
}

# API Gateway
module "dga-apigw" {
  source = "./module/apigw"
  dga-nlb-dns = module.dga-elb.dga-nlb-dns
  dga-nlb-id = module.dga-elb.dga-nlb-id
  cognito-arn = module.dga-cognito.cognito-arn
}

# Cognito
module "dga-cognito" {
  source = "./module/cognito"
  google_id = var.google_id
  google_secret = var.google_secret
}

# RDS
module "dga-rds" {
  source = "./module/rds"
  db-subs = [module.dga-vpc.dga-pri-1-id, module.dga-vpc.dga-pri-2-id]
  db-sg = module.dga-sg.dga-pri-db-sg-id
  db-password = var.db-password
}

# Docdb
module "dga-docdb" {
  source = "./module/docdb"
  db-subgroup = module.dga-rds.db-subgroup
  db-password = var.db-password
  db-sg        = module.dga-sg.dga-pri-db-sg-id
}

# S3
module "dga-s3" {
  source = "./module/s3"
}

# Route53
module "dga-route53" {
  source = "./module/route53"
  domain = var.domain
  domain_name = module.dga-cloudfront.domain_name
  hosted_zone_id = module.dga-cloudfront.hosted_zone_id
}

# CloudFront
module "dga-cloudfront" {
  source = "./module/cloudfront"
  domain = var.domain
  apigw-id = module.dga-apigw.apigw-id
  s3-id = module.dga-s3.s3-id
  cert-arn = module.dga-iam.cert-arn
  region = var.region
}

# Iam
module "dga-iam" {
  providers = {
    aws = aws.acm
  }
  source = "./module/iam"
  domain = var.domain
  zone-id = module.dga-route53.zone-id
}