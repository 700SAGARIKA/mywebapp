aws_region         = "ap-south-1"
account_id         = "706059253979"
environment        = "prod"
cluster_name       = "my-eks-cluster-prod"
ecr_repo_name      = "ecs-app"

node_instance_type = "t3.large"
node_desired_size  = 3
node_min_size      = 2
node_max_size      = 6
node_disk_size     = 30
