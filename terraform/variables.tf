variable "aws_region" { default = "ap-south-1" }
variable "account_id" { default = "706059253979" }
variable "cluster_name" { default = "my-eks-cluster-tf" }
variable "ecr_repo_name" { default = "ecs-app" }
variable "environment" { default = "dev" }

variable "vpc_cidr" { default = "10.0.0.0/16" }
variable "private_subnets" { default = ["10.0.1.0/24", "10.0.2.0/24"] }
variable "public_subnets" { default = ["10.0.101.0/24", "10.0.102.0/24"] }

variable "node_instance_type" { default = "t3.medium" }
variable "node_desired_size" { default = 2 }
variable "node_min_size" { default = 1 }
variable "node_max_size" { default = 3 }
variable "node_disk_size" { default = 20 }
