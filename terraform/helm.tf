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
  # cloudWatchLogs (not cloudWatch) is the output block this chart actually
  # enables by default - the old cloudWatch.* sets here were targeting a
  # disabled block and had no effect, which is why logs were landing in
  # /aws/eks/fluentbit-cloudwatch/logs in us-east-1 instead of here.
  set {
    name  = "cloudWatchLogs.region"
    value = var.aws_region
  }
  set {
    name  = "cloudWatchLogs.logGroupName"
    value = "/aws/eks/fluentbit-cloudwatch/logs"
  }

  depends_on = [module.eks, module.fluent_bit_irsa]
}

resource "helm_release" "prometheus_stack" {
  name             = "kube-prometheus-stack"
  chart            = "${path.module}/charts/kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true

  set {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password # add this to variables.tf + tfvars
  }

  # Grafana's default install has no persistent volume - its sqlite DB (admin
  # user email, any in-UI changes) lives in ephemeral pod storage and resets
  # to factory defaults on every pod restart. Give it a real PVC so account
  # state actually survives upgrades/restarts.
  set {
    name  = "grafana.persistence.enabled"
    value = "true"
  }
  set {
    name  = "grafana.persistence.storageClassName"
    value = "gp2"
  }
  set {
    name  = "grafana.persistence.size"
    value = "5Gi"
  }

  # Grafana's PVC is ReadWriteOnce - only one pod can mount it at a time.
  # The chart's default RollingUpdate strategy tries to bring up the new pod
  # before killing the old one on any pod-template change; since a single
  # RWO volume can't attach to both, the new pod deadlocks in Init forever
  # (FailedAttachVolume: Multi-Attach error) and helm --wait hangs until
  # Terraform's apply times out. Recreate tears down the old pod first.
  set {
    name  = "grafana.deploymentStrategy.type"
    value = "Recreate"
  }

  # Grafana chart validates that secrets aren't passed in plain values — disable
  # so smtp.password can be injected directly from var.smtp_password
  set {
    name  = "grafana.assertNoLeakedSecrets"
    value = "false"
  }

  # Without an explicit root_url, Grafana guesses its own public address for
  # any self-generated absolute link (password reset emails, invites) and
  # falls back to the container's internal port 3000 instead of the ALB's
  # 443 - reset emails end up pointing at a port nothing external can reach.
  set {
    name  = "grafana.grafana\\.ini.server.root_url"
    value = "https://grafana.ordr.fun/"
  }
  set {
    name  = "grafana.grafana\\.ini.server.domain"
    value = "grafana.ordr.fun"
  }

  # Grafana built-in SMTP — enables email from Grafana-native contact points
  set {
    name  = "grafana.grafana\\.ini.smtp.enabled"
    value = "true"
  }
  set {
    name  = "grafana.grafana\\.ini.smtp.host"
    value = var.smtp_host
  }
  set {
    name  = "grafana.grafana\\.ini.smtp.user"
    value = "sagarika.mishra@vvdntech.in"
  }
  set {
    name  = "grafana.grafana\\.ini.smtp.password"
    value = var.smtp_password
  }
  set {
    name  = "grafana.grafana\\.ini.smtp.from_address"
    value = "sagarika.mishra@vvdntech.in"
  }
  set {
    name  = "grafana.grafana\\.ini.smtp.from_name"
    value = "Grafana Alerts"
  }

  # Let the dashboard sidecar file provisioned dashboards into folders based on
  # a configmap annotation, so dashboards-as-code can land in nested folders
  # (e.g. "app.dashboard/Namespaces-pannel") instead of always landing in General.
  set {
    name  = "grafana.sidecar.dashboards.folderAnnotation"
    value = "grafana_folder"
  }
  set {
    name  = "grafana.sidecar.dashboards.provider.foldersFromFilesStructure"
    value = "true"
  }

  # IRSA so Grafana's CloudWatch datasource can query the log group fluent-bit ships to
  set {
    name  = "grafana.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.grafana_cloudwatch_irsa.iam_role_arn
  }

  # CloudWatch Logs datasource - points at the log group fluent-bit actually
  # populates today (see iam.tf note on the cloudWatch vs cloudWatchLogs mismatch)
  #
  # uid is pinned explicitly (dashboards/namespace-resources.json's log panel
  # references uid "cloudwatch" directly) - without it Grafana auto-generates
  # a random uid on provisioning and any dashboard referencing "cloudwatch"
  # can never resolve the datasource.
  set {
    name  = "grafana.additionalDataSources[0].name"
    value = "CloudWatch"
  }
  set {
    name  = "grafana.additionalDataSources[0].uid"
    value = "cloudwatch"
  }
  set {
    name  = "grafana.additionalDataSources[0].type"
    value = "cloudwatch"
  }
  set {
    name  = "grafana.additionalDataSources[0].access"
    value = "proxy"
  }
  set {
    name  = "grafana.additionalDataSources[0].jsonData.authType"
    value = "default"
  }
  set {
    name  = "grafana.additionalDataSources[0].jsonData.defaultRegion"
    value = var.aws_region
  }
  set {
    name  = "grafana.additionalDataSources[0].editable"
    value = "false"
  }

  # Expose Grafana via your ALB ingress
  set {
    name  = "grafana.ingress.enabled"
    value = "true"
  }
  set {
    name  = "grafana.ingress.ingressClassName"
    value = "alb"
  }
  set {
    name  = "grafana.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/scheme"
    value = "internet-facing"
  }
  set {
    name  = "grafana.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/target-type"
    value = "ip"
  }
  set {
    name  = "grafana.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/listen-ports"
    value = "[{\"HTTP\":80}\\,{\"HTTPS\":443}]"
  }
  set {
    name  = "grafana.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/ssl-redirect"
    value = "443"
    type  = "string"
  }
  set {
    name  = "grafana.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/certificate-arn"
    value = var.acm_certificate_arn
  }
  set {
    name  = "grafana.ingress.hosts[0]"
    value = "grafana.ordr.fun"
  }

  # Keep Prometheus internal (no public ingress needed)
  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "15d"
  }

  # EKS hides control plane components — these rules always fire as false positives
  set {
    name  = "defaultRules.rules.kubeControllerManager"
    value = "false"
  }
  set {
    name  = "defaultRules.rules.kubeSchedulerAlerting"
    value = "false"
  }
  set {
    name  = "defaultRules.rules.kubeSchedulerRecording"
    value = "false"
  }

  # Alertmanager — email via corporate SMTP
  set {
    name  = "alertmanager.config.global.smtp_smarthost"
    value = var.smtp_host
  }
  set {
    name  = "alertmanager.config.global.smtp_from"
    value = "sagarika.mishra@vvdntech.in"
  }
  set {
    name  = "alertmanager.config.global.smtp_auth_username"
    value = "sagarika.mishra@vvdntech.in"
  }
  set {
    name  = "alertmanager.config.global.smtp_auth_password"
    value = var.smtp_password
  }
  set {
    name  = "alertmanager.config.global.smtp_require_tls"
    value = "true"
  }

  # Route all alerts to email by default
  set {
    name  = "alertmanager.config.route.receiver"
    value = "email-alerts"
  }
  set {
    name  = "alertmanager.config.route.group_by[0]"
    value = "alertname"
  }
  set {
    name  = "alertmanager.config.route.group_wait"
    value = "30s"
  }
  set {
    name  = "alertmanager.config.route.group_interval"
    value = "5m"
  }
  set {
    name  = "alertmanager.config.route.repeat_interval"
    value = "12h"
  }

  # Email receiver - added as receivers[1], NOT receivers[0]. The chart's
  # default receivers[0] is the built-in "null" receiver that the default
  # route.routes[0] (mutes the Watchdog heartbeat alert) points at; renaming
  # receivers[0] breaks that reference with "undefined receiver \"null\" used
  # in route" and makes the operator reject the whole config.
  #
  # receivers[0] must ALSO be set explicitly (not just left alone) - Helm's
  # --set does not deep-merge list elements with the chart's default values,
  # so setting only receivers[1].* replaces the whole receivers list and
  # leaves index 0 as a bare `null` instead of preserving the chart's default
  # {name: "null"} object, which reproduces the same "undefined receiver"
  # error from a different cause.
  set {
    name  = "alertmanager.config.receivers[0].name"
    value = "null"
    type  = "string"   # without this, YAML parses null as None not the string "null"
  }
  set {
    name  = "alertmanager.config.receivers[1].name"
    value = "email-alerts"
  }
  set {
    name  = "alertmanager.config.receivers[1].email_configs[0].to"
    value = "sagarika.mishra@vvdntech.in"
  }
  set {
    name  = "alertmanager.config.receivers[1].email_configs[0].send_resolved"
    value = "true"
  }

  depends_on = [module.eks, helm_release.alb_controller, module.grafana_cloudwatch_irsa]
}
