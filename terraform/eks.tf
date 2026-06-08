module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.32"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    ng-clean = {
      instance_types = [var.node_instance_type]
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size
      disk_size      = var.node_disk_size

      # Matches your existing taint in values.yaml
      taints = [
        {
          key    = "dedicated"
          value  = "apps"
          effect = "NO_SCHEDULE"
        }
      ]

      labels = { role = "apps" }
    }
  }

  tags = { Environment = var.environment }
}
