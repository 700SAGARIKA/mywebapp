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

# grafana_admin_password intentionally not set here - a -var-file value takes
# precedence over TF_VAR_grafana_admin_password env vars in Terraform, so
# hardcoding even a placeholder here silently defeats CI's credential
# injection. Supply it only via TF_VAR_grafana_admin_password.
acm_certificate_arn = "arn:aws:acm:ap-south-1:706059253979:certificate/f7509764-6279-4de0-939a-58a8d8428c2e"
