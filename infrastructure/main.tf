# VPC
module "vpc" {
  source               = "./modules/vpc"
  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  tags                 = var.tags
}

# S3 artifacts/static
module "s3" {
  source       = "./modules/s3"
  bucket_name  = var.artifact_bucket_name
  project_name = var.project_name
  tags         = var.tags
}

# IAM (EC2 role + GitHub OIDC deploy role)
module "iam" {
  source        = "./modules/iam"
  project_name  = var.project_name
  artifact_bucket_arn = module.s3.bucket_arn
  github_org    = var.github_org
  github_repo   = var.github_repo
  tags          = var.tags
}

# Security groups
module "sg" {
  source          = "./modules/security_groups"
  vpc_id          = module.vpc.vpc_id
  project_name    = var.project_name
  tags            = var.tags
}

# ALB
module "alb" {
  source             = "./modules/alb"
  project_name       = var.project_name
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  alb_sg_id          = module.sg.alb_sg_id
  tags               = var.tags
}

# EC2 - Staging
module "ec2_staging" {
  source              = "./modules/ec2"
  project_name        = var.project_name
  env_name            = "staging"
  subnet_id           = module.vpc.private_subnet_ids[0]
  instance_type       = var.instance_type
  instance_sg_id      = module.sg.instance_sg_id
  iam_instance_profile= module.iam.instance_profile_name
  target_group_arn    = module.alb.tg_staging_arn
  user_data_vars = {
    APP_ENV = "staging"
  }
  tags = merge(var.tags, { Environment = "staging" })
}

# EC2 - Production
module "ec2_prod" {
  source              = "./modules/ec2"
  project_name        = var.project_name
  env_name            = "prod"
  subnet_id           = module.vpc.private_subnet_ids[1]
  instance_type       = var.instance_type
  instance_sg_id      = module.sg.instance_sg_id
  iam_instance_profile= module.iam.instance_profile_name
  target_group_arn    = module.alb.tg_prod_arn
  user_data_vars = {
    APP_ENV = "prod"
  }
  tags = merge(var.tags, { Environment = "prod" })
}

# Secrets
module "secrets" {
  source        = "./modules/secrets"
  project_name  = var.project_name
  tags          = var.tags
}
