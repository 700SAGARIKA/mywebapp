pipeline {
    agent any

    options {
        timestamps()
    }

    parameters {
        string(
            name: 'IMAGE_TAG',
            defaultValue: '',
            description: 'Docker Image Tag (leave empty to use build number)'
        )
    }

    environment {
        AWS_REGION   = "ap-south-1"
        ECR_REPO     = "ecs-app"
        ECR_REGISTRY = "706059253979.dkr.ecr.ap-south-1.amazonaws.com"
    }

    stages {

        stage("Checkout") {
            steps {
                checkout scm
            }
        }

        stage("Select Environment") {
            steps {
                script {
                    timeout(time: 30, unit: 'MINUTES') {
                        env.ENVIRONMENT = input(
                            message: 'Select deployment environment',
                            parameters: [
                                choice(name: 'ENVIRONMENT', choices: ['dev', 'prod'], description: 'Target environment')
                            ]
                        )
                    }
                    env.CLUSTER_NAME = env.ENVIRONMENT == 'prod' ? 'my-eks-cluster-prod' : 'my-eks-cluster-tf'
                }
            }
        }

        stage("Build Started Notification") {
            steps {
                script {
                    env.BUILD_START_TIME = System.currentTimeMillis().toString()

                    def cause = currentBuild.getBuildCauses()[0]
                    env.TRIGGERED_BY = cause?.userId ?: cause?.shortDescription ?: 'Automated/Unknown'

                    env.GIT_BRANCH_NAME = sh(
                        script: "git rev-parse --abbrev-ref HEAD",
                        returnStdout: true
                    ).trim()

                    env.GIT_COMMIT_ID = sh(
                        script: "git rev-parse HEAD",
                        returnStdout: true
                    ).trim()
                }

                emailext(
                    subject: "STARTED: ${JOB_NAME} #${BUILD_NUMBER} | ${env.ENVIRONMENT.toUpperCase()}",
                    body: """
Build started for ${env.ENVIRONMENT.toUpperCase()} environment.

Triggered By  : ${env.TRIGGERED_BY}
Job Name      : ${JOB_NAME}
Build Number  : ${BUILD_NUMBER}
Branch        : ${env.GIT_BRANCH_NAME}
Commit        : ${env.GIT_COMMIT_ID}
Environment   : ${env.ENVIRONMENT}
Cluster       : ${env.CLUSTER_NAME}

${BUILD_URL}console
""",
                    to: "sagarika.mishra@vvdntech.in",
                    attachLog: false
                )
            }
        }

        stage("Build Docker Image") {
            steps {
                script {
                    env.TAG = params.IMAGE_TAG?.trim()
                        ? params.IMAGE_TAG.trim()
                        : BUILD_NUMBER
                }
                sh "docker build -t ${ECR_REPO}:${env.TAG} ."
            }
        }

        stage("Login to ECR") {
            steps {
                sh """
                    aws ecr get-login-password --region ${AWS_REGION} | \
                    docker login --username AWS --password-stdin ${ECR_REGISTRY}
                """
            }
        }

        stage("Tag and Push Docker Image") {
            steps {
                sh """
                    docker tag ${ECR_REPO}:${env.TAG} ${ECR_REGISTRY}/${ECR_REPO}:${env.TAG}
                    docker push ${ECR_REGISTRY}/${ECR_REPO}:${env.TAG}

                    # Each build tags a new ecs-app:<build_number> image, and Docker
                    # never garbage-collects layers referenced by a tag - left alone
                    # this fills the agent's disk after enough builds ("no space left
                    # on device"). The image lives in ECR now, so the local copies
                    # aren't needed - remove them and prune dangling build cache.
                    docker rmi ${ECR_REPO}:${env.TAG} ${ECR_REGISTRY}/${ECR_REPO}:${env.TAG} || true
                    docker image prune -f
                """
            }
        }

        stage("Download Helm Charts") {
            steps {
                sh """
                    mkdir -p terraform/charts
                    cd terraform/charts
                    curl --insecure -sL "https://aws.github.io/eks-charts/aws-load-balancer-controller-3.4.0.tgz" -o alb.tgz
                    curl --insecure -sL "https://aws.github.io/eks-charts/aws-for-fluent-bit-0.2.0.tgz" -o fluent-bit.tgz
                    curl --insecure -sL "https://github.com/kubernetes/autoscaler/releases/download/cluster-autoscaler-chart-9.57.0/cluster-autoscaler-9.57.0.tgz" -o autoscaler.tgz
                    curl --insecure -sL "https://github.com/kubernetes-sigs/metrics-server/releases/download/metrics-server-helm-chart-3.13.0/metrics-server-3.13.0.tgz" -o metrics-server.tgz
                    curl --insecure -sL "https://github.com/kubernetes-sigs/external-dns/releases/download/external-dns-helm-chart-1.21.1/external-dns-1.21.1.tgz" -o external-dns.tgz
                    curl --insecure -sL "https://github.com/prometheus-community/helm-charts/releases/download/kube-prometheus-stack-61.3.2/kube-prometheus-stack-61.3.2.tgz" -o prometheus-stack.tgz
                    for f in *.tgz; do tar -xzf "\$f"; done

                    # CA bundle for Terraform Helm provider TLS
                    curl --insecure -sL https://curl.se/ca/cacert.pem -o ../cacerts.pem
                """
            }
        }

        stage("Terraform Infra") {
            steps {
                withCredentials([
                    string(credentialsId: 'GRAFANA_ADMIN_PASSWORD', variable: 'GRAFANA_ADMIN_PASSWORD'),
                    usernamePassword(credentialsId: '35735d98-ba29-44c1-a304-4b449383569f', usernameVariable: 'SMTP_USERNAME', passwordVariable: 'SMTP_PASSWORD')
                ]) {
                    dir('terraform') {
                        sh """
                            terraform init \
                                -backend-config=backends/${env.ENVIRONMENT}.tfbackend \
                                -reconfigure

                            TF_VAR_grafana_admin_password=\${GRAFANA_ADMIN_PASSWORD} \
                            TF_VAR_smtp_password=\${SMTP_PASSWORD} \
                            terraform apply -auto-approve \
                                -var-file=envs/${env.ENVIRONMENT}.tfvars
                        """
                    }
                }
            }
        }

        stage("Approval Gate (prod only)") {
            when {
                expression { env.ENVIRONMENT == 'prod' }
            }
            steps {
                timeout(time: 15, unit: 'MINUTES') {
                    input message: "Deploy build #${BUILD_NUMBER} to PRODUCTION?",
                          ok: "Deploy"
                }
            }
        }

        stage("Deploy to EKS") {
            steps {
                sh """
                    aws eks update-kubeconfig \
                        --region ${AWS_REGION} \
                        --name ${env.CLUSTER_NAME}

                    helm upgrade --install ecs-app ./ecs-app \
                        --namespace default \
                        --wait \
                        --timeout 5m \
                        --set image.repository=${ECR_REGISTRY}/${ECR_REPO} \
                        --set image.tag=${env.TAG} \
                        --set podLabels.environment=${env.ENVIRONMENT} \
                        --set serviceAccount.annotations."eks\\.amazonaws\\.com/role-arn"=arn:aws:iam::706059253979:role/${env.ENVIRONMENT}-ecs-app-irsa-role

                    kubectl rollout status deployment/ecs-app -n default
                """
            }
        }
    }

    post {
        success {
            script {
                def durationMs = System.currentTimeMillis() - env.BUILD_START_TIME.toLong()
                def durationMin = (durationMs / 60000).toInteger()
                def durationSec = ((durationMs % 60000) / 1000).toInteger()
                env.BUILD_DURATION = "${durationMin}m ${durationSec}s"
            }
            emailext(
                subject: "SUCCESS: ${JOB_NAME} #${BUILD_NUMBER} | ${env.ENVIRONMENT.toUpperCase()}",
                body: """
Build succeeded for ${env.ENVIRONMENT.toUpperCase()} environment.

Triggered By  : ${env.TRIGGERED_BY}
Job Name      : ${JOB_NAME}
Build Number  : ${BUILD_NUMBER}
Branch        : ${env.GIT_BRANCH_NAME}
Commit        : ${env.GIT_COMMIT_ID}
Duration      : ${env.BUILD_DURATION}
Environment   : ${env.ENVIRONMENT}
Cluster       : ${env.CLUSTER_NAME}
Docker Image  : ${ECR_REGISTRY}/${ECR_REPO}:${env.TAG}

${BUILD_URL}console
""",
                to: "sagarika.mishra@vvdntech.in",
                attachLog: true,
                compressLog: true
            )
        }

        failure {
            script {
                def durationMs = System.currentTimeMillis() - env.BUILD_START_TIME.toLong()
                def durationMin = (durationMs / 60000).toInteger()
                def durationSec = ((durationMs % 60000) / 1000).toInteger()
                env.BUILD_DURATION = "${durationMin}m ${durationSec}s"
            }
            emailext(
                subject: "FAILED: ${JOB_NAME} #${BUILD_NUMBER} | ${env.ENVIRONMENT.toUpperCase()}",
                body: """
Build FAILED for ${env.ENVIRONMENT.toUpperCase()} environment.

Triggered By  : ${env.TRIGGERED_BY}
Job Name      : ${JOB_NAME}
Build Number  : ${BUILD_NUMBER}
Branch        : ${env.GIT_BRANCH_NAME}
Commit        : ${env.GIT_COMMIT_ID}
Duration      : ${env.BUILD_DURATION}
Environment   : ${env.ENVIRONMENT}

${BUILD_URL}console
""",
                to: "sagarika.mishra@vvdntech.in",
                attachLog: true,
                compressLog: true
            )
        }
    }
}
