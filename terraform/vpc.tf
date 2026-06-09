locals {
  vpc_id             = "vpc-01b737f34efe32d60"
  private_subnet_ids = ["subnet-0c47c670c1fec2122", "subnet-0001c148d4932b6fe"]
  public_subnet_ids  = ["subnet-083223b7553cee9d6", "subnet-0339d44a813fa0202"]
}

resource "aws_ec2_tag" "private_subnet_internal_elb" {
  for_each    = toset(local.private_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

resource "aws_ec2_tag" "private_subnet_cluster" {
  for_each    = toset(local.private_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/cluster/${var.cluster_name}"
  value       = "shared"
}

resource "aws_ec2_tag" "public_subnet_elb" {
  for_each    = toset(local.public_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

resource "aws_ec2_tag" "public_subnet_cluster" {
  for_each    = toset(local.public_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/cluster/${var.cluster_name}"
  value       = "shared"
}
