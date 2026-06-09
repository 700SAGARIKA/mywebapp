pipeline {
    agent any

    options {
        timestamps()
    }

    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'prod'],
            description: 'Deployment Environment'
        )

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
        CLUSTER_NAME = "${params.ENVIRONMENT == 'prod' ? 'my-eks-cluster-prod' : 'my-eks-cluster-dev'}"
    }

    stages {

        stage("Checkout") {
            steps {
                checkout scm
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
                    subject: "STARTED: ${JOB_NAME} #${BUILD_NUMBER} | ${params.ENVIRONMENT.toUpperCase()}",
                    body: """
Build started for ${params.ENVIRONMENT.toUpperCase()} environment.

Triggered By  : ${env.TRIGGERED_BY}
Job Name      : ${JOB_NAME}
Build Number  : ${BUILD_NUMBER}
Branch        : ${env.GIT_BRANCH_NAME}
Commit        : ${env.GIT_COMMIT_ID}
Environment   : ${params.ENVIRONMENT}
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
                """
            }
        }

        stage("Terraform Infra") {
            steps {
                dir('terraform') {
                    sh """
                        terraform init \
                            -backend-config=backends/${params.ENVIRONMENT}.tfbackend \
                            -reconfigure

                        terraform apply -auto-approve \
                            -var-file=envs/${params.ENVIRONMENT}.tfvars
                    """
                }
            }
        }

        stage("Approval Gate (prod only)") {
            when {
                expression { params.ENVIRONMENT == 'prod' }
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
                        --set podLabels.environment=${params.ENVIRONMENT}

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
                subject: "SUCCESS: ${JOB_NAME} #${BUILD_NUMBER} | ${params.ENVIRONMENT.toUpperCase()}",
                body: """
Build succeeded for ${params.ENVIRONMENT.toUpperCase()} environment.

Triggered By  : ${env.TRIGGERED_BY}
Job Name      : ${JOB_NAME}
Build Number  : ${BUILD_NUMBER}
Branch        : ${env.GIT_BRANCH_NAME}
Commit        : ${env.GIT_COMMIT_ID}
Duration      : ${env.BUILD_DURATION}
Environment   : ${params.ENVIRONMENT}
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
                subject: "FAILED: ${JOB_NAME} #${BUILD_NUMBER} | ${params.ENVIRONMENT.toUpperCase()}",
                body: """
Build FAILED for ${params.ENVIRONMENT.toUpperCase()} environment.

Triggered By  : ${env.TRIGGERED_BY}
Job Name      : ${JOB_NAME}
Build Number  : ${BUILD_NUMBER}
Branch        : ${env.GIT_BRANCH_NAME}
Commit        : ${env.GIT_COMMIT_ID}
Duration      : ${env.BUILD_DURATION}
Environment   : ${params.ENVIRONMENT}

${BUILD_URL}console
""",
                to: "sagarika.mishra@vvdntech.in",
                attachLog: true,
                compressLog: true
            )
        }
    }
}
