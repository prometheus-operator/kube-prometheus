###############
## Providers ##
###############

provider "aws" {
  region = local.aws_region
}

################################
## Terraform Required Version ##
################################

terraform {
  required_version = ">= 0.12"
}

#############################
## Global Variables Module ##
#############################

module "global_variables" {
  source  = "app.terraform.io/stash/variables/global"
  version = "~>0.9"
}

locals {
  # General
  aws_account_name = var.workspace_account
  aws_account_id   = module.global_variables.aws_account_id[var.workspace_account]
  aws_region       = module.global_variables.aws_region[var.workspace_account]
  environment      = var.workspace_environment

  # Networking
  vpc_id          = module.global_variables.aws_vpc_id[var.workspace_account][var.workspace_environment]
  priv_subnet_ids = module.global_variables.aws_priv_subnet_ids[var.workspace_account][var.workspace_environment]

  # Security Group
  dmz_ingress_vpc_cidr     = module.global_variables.aws_vpc_cidr_block["dmz"]["ingress"]
  dmz_dev_priv_subnet_cidr = join(",", module.global_variables.aws_subnet_priv_cidrs["dmz"][var.workspace_environment])
  vpc_cidr_block           = module.global_variables.aws_vpc_cidr_block[var.workspace_account][var.workspace_environment]
}

############################
## Kubernetes Dev Workers ##
############################

module "k8s_prometheus" {
  source  = "app.terraform.io/stash/k8s-wk/aws"
  version = "~>0.5.0"

  # General
  app_name         = var.app_name
  aws_account_name = local.aws_account_name
  aws_region       = local.aws_region
  environment      = local.environment

  # IAM
  additional_assume_role = true
  assume_role_arns       = ["arn:aws:iam::411965268865:role/metrics-test-role"]

  # Networking
  vpc_id          = local.vpc_id
  vpc_cidr_block  = local.vpc_cidr_block
  priv_subnet_ids = local.priv_subnet_ids
}

resource "aws_security_group_rule" "allow_nodeport" {
  type              = "ingress"
  from_port         = 30000
  to_port           = 32767
  protocol          = "tcp"
  security_group_id = module.k8s_prometheus.k8s_wk_sg_id
  cidr_blocks = [
    local.vpc_cidr_block,          #SecOps Dev
    local.dmz_dev_priv_subnet_cidr #DMZ Dev
  ]
}
