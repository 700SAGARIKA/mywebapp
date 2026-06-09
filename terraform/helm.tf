resource "helm_release" "alb_controller" {
  name      = "aws-load-balancer-controller"
  chart     = "${path.module}/charts/aws-load-balancer-controller"
  namespace = "kube-system"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.alb_controller_irsa.iam_role_arn
  }
  set {
    name  = "region"
    value = var.aws_region
  }
  set {
    name  = "vpcId"
    value = local.vpc_id
  }

  depends_on = [module.eks, module.alb_controller_irsa]
}

resource "helm_release" "cluster_autoscaler" {
  name      = "cluster-autoscaler"
  chart     = "${path.module}/charts/cluster-autoscaler"
  namespace = "kube-system"

  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster_name
  }
  set {
    name  = "awsRegion"
    value = var.aws_region
  }
  set {
    name  = "rbac.serviceAccount.name"
    value = "cluster-autoscaler"
  }
  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.cluster_autoscaler_irsa.iam_role_arn
  }

  depends_on = [module.eks, module.cluster_autoscaler_irsa]
}

resource "helm_release" "metrics_server" {
  name      = "metrics-server"
  chart     = "${path.module}/charts/metrics-server"
  namespace = "kube-system"

  depends_on = [module.eks]
}

resource "helm_release" "external_dns" {
  name      = "external-dns"
  chart     = "${path.module}/charts/external-dns"
  namespace = "kube-system"

  set {
    name  = "provider"
    value = "aws"
  }
  set {
    name  = "aws.region"
    value = var.aws_region
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.external_dns_irsa.iam_role_arn
  }

  depends_on = [module.eks, module.external_dns_irsa]
}

resource "helm_release" "fluent_bit" {
  name      = "aws-for-fluent-bit"
  chart     = "${path.module}/charts/aws-for-fluent-bit"
  namespace = "kube-system"

  set {
    name  = "serviceAccount.name"
    value = "fluent-bit"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.fluent_bit_irsa.iam_role_arn
  }
  set {
    name  = "cloudWatch.region"
    value = var.aws_region
  }
  set {
    name  = "cloudWatch.logGroupName"
    value = "/eks/${var.cluster_name}/app"
  }

  depends_on = [module.eks, module.fluent_bit_irsa]
}
