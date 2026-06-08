terraform {
  backend "s3" {
    bucket         = "my-eks-terraform-state-706059253979"
    key            = "eks/terraform.tfstate"
    region         = "ap-south-1"
    use_lockfile   = true
    encrypt        = true
  }
}