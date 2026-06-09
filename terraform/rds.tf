data "aws_db_instance" "app" {
  db_instance_identifier = "database-prj"
}

resource "aws_security_group_rule" "rds_from_eks_nodes" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = tolist(data.aws_db_instance.app.vpc_security_groups)[0]
  source_security_group_id = module.eks.node_security_group_id
  description              = "EKS nodes to RDS PostgreSQL"
}
