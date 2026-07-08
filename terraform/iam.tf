# IRSA for AWS Load Balancer Controller
module "alb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.environment}-aws-load-balancer-controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

# IRSA for your app (ecs-app-sa in default namespace)
module "app_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.environment}-ecs-app-irsa-role"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["default:ecs-app-sa"]
    }
  }
}


module "cluster_autoscaler_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                        = "${var.environment}-cluster-autoscaler"
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_names = [var.cluster_name]

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }
}

module "external_dns_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                     = "${var.environment}-external-dns"
  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = ["arn:aws:route53:::hostedzone/*"]

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:external-dns"]
    }
  }
}

# Policy granting app access to its Secrets Manager secret
resource "aws_iam_policy" "app_secrets" {
  name = "${var.environment}-ecs-app-secrets-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = "arn:aws:secretsmanager:${var.aws_region}:${var.account_id}:secret:my_postgres*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "app_secrets" {
  role       = module.app_irsa.iam_role_name
  policy_arn = aws_iam_policy.app_secrets.arn
}

module "fluent_bit_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                              = "${var.environment}-fluent-bit"
  attach_cloudwatch_observability_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:fluent-bit"]
    }
  }
}

# Lets Grafana's CloudWatch datasource read pod logs shipped by fluent-bit,
# so logs can be viewed in Grafana next to the CPU/memory dashboards.
module "grafana_cloudwatch_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.environment}-grafana-cloudwatch-logs"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["monitoring:kube-prometheus-stack-grafana"]
    }
  }
}

resource "aws_iam_policy" "grafana_cloudwatch_logs" {
  name = "${var.environment}-grafana-cloudwatch-logs-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:DescribeLogGroups"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:GetLogGroupFields",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults",
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/aws/eks/fluentbit-cloudwatch/logs:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "grafana_cloudwatch_logs" {
  role       = module.grafana_cloudwatch_irsa.iam_role_name
  policy_arn = aws_iam_policy.grafana_cloudwatch_logs.arn
}

output "alb_controller_role_arn" { value = module.alb_controller_irsa.iam_role_arn }
output "app_irsa_role_arn" { value = module.app_irsa.iam_role_arn }
