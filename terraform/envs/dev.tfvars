aws_region         = "ap-south-1"
account_id         = "706059253979"
environment        = "dev"
cluster_name       = "my-eks-cluster-tf"
ecr_repo_name      = "ecs-app"

node_instance_type = "t3.medium"
node_desired_size  = 2
node_min_size      = 1
node_max_size      = 3
node_disk_size     = 20
