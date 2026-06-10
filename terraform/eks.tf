module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.32"

  vpc_id     = local.vpc_id
  subnet_ids = local.private_subnet_ids

  cluster_endpoint_public_access           = true
  cluster_endpoint_private_access          = true
  enable_cluster_creator_admin_permissions = false

  cluster_security_group_additional_rules = {
    vpc_ingress = {
      description = "Allow all VPC traffic to EKS API"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "ingress"
      cidr_blocks = ["10.0.0.0/16"]
    }
  }

  access_entries = {
  jenkins = {
    principal_arn = "arn:aws:iam::${var.account_id}:role/ec2-role"
    policy_associations = {
      admin = {
        policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        access_scope = { type = "cluster" }
      }
    }
  }
  root = {
    principal_arn = "arn:aws:iam::${var.account_id}:root"
    policy_associations = {
      admin = {
        policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        access_scope = { type = "cluster" }
      }
    }
  }
}


  eks_managed_node_groups = {
    ng-clean = {
      instance_types = [var.node_instance_type]
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size
      disk_size      = var.node_disk_size

      labels = { role = "apps" }
    }
  }

  cluster_addons = {
    coredns    = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni    = { most_recent = true }
  }


  tags = { Environment = var.environment }
}
