pipeline {
    agent any

    options {
        timestamps()
    }

    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'stage', 'prod'],
            description: 'Deployment Environment'
        )

        string(
            name: 'IMAGE_TAG',
            defaultValue:'',
            description: 'Docker Image Tag'
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
                    subject: "STARTED: ${JOB_NAME} #${BUILD_NUMBER} | ${params.ENVIRONMENT.toUpperCase()} SETUP",
                    body: """
This is notified to you: Job Triggered on ${params.ENVIRONMENT.toUpperCase()} SETUP

Build Triggered By : ${env.TRIGGERED_BY}
Job Name           : ${JOB_NAME}
Build Number       : ${BUILD_NUMBER}
Branch Name        : ${env.GIT_BRANCH_NAME}
Commit ID          : ${env.GIT_COMMIT_ID}
Environment        : ${params.ENVIRONMENT}

Check console output at:
${BUILD_URL}console

-- ${BUILD_NUMBER}
""",
                    to: "sagarika.mishra@vvdntech.in",
                    attachLog: true,
                    compressLog: true
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

                sh """
                    docker build -t ${ECR_REPO}:${env.TAG} .
                """
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

        stage("Tag Docker Image") {
            steps {
                sh """
                    docker tag ${ECR_REPO}:${env.TAG} \
                    ${ECR_REGISTRY}/${ECR_REPO}:${env.TAG}
                """
            }
        }

        stage("Push Docker Image") {
            steps {
                sh """
                    docker push ${ECR_REGISTRY}/${ECR_REPO}:${env.TAG}
                """
            }
        }

        stage("Terraform Infra") {
    when {
        expression { params.ENVIRONMENT == 'prod' }  // or always
    }
    steps {
        dir('terraform') {
            sh """
                terraform init
                terraform workspace select ${params.ENVIRONMENT} || terraform workspace new ${params.ENVIRONMENT}
                terraform apply -auto-approve \
                    -var="environment=${params.ENVIRONMENT}"
            """
        }
    }
}


        stage("Deploy to EKS") {
            steps {
                sh """
                    aws eks update-kubeconfig \
                        --region ${AWS_REGION} \
                        --name my-eks-cluster-tf

                    helm upgrade --install ecs-app ./ecs-app \
                        --namespace default \
                        --wait \
                        --timeout 5m \
                        --set image.repository=${ECR_REGISTRY}/${ECR_REPO} \
                        --set image.tag=${env.TAG}

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

                env.BUILD_DURATION = "${durationMin} min ${durationSec} sec"
            }

            emailext(
                subject: "SUCCESS: ${JOB_NAME} #${BUILD_NUMBER} | ${params.ENVIRONMENT.toUpperCase()} SETUP",
                body: """
This is notified to you: Job Succeeded on ${params.ENVIRONMENT.toUpperCase()} SETUP

Build Triggered By : ${env.TRIGGERED_BY}
Job Name           : ${JOB_NAME}
Build Number       : ${BUILD_NUMBER}
Branch Name        : ${env.GIT_BRANCH_NAME}
Commit ID          : ${env.GIT_COMMIT_ID}
Build Duration     : ${env.BUILD_DURATION}
Environment        : ${params.ENVIRONMENT}
Docker Image       : ${ECR_REGISTRY}/${ECR_REPO}:${env.TAG}

Check console output at:
${BUILD_URL}console

-- ${BUILD_NUMBER}
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

                env.BUILD_DURATION = "${durationMin} min ${durationSec} sec"
            }

            emailext(
                subject: "FAILED: ${JOB_NAME} #${BUILD_NUMBER} | ${params.ENVIRONMENT.toUpperCase()} SETUP",
                body: """
This is notified to you: Job FAILED on ${params.ENVIRONMENT.toUpperCase()} SETUP

Build Triggered By : ${env.TRIGGERED_BY}
Job Name           : ${JOB_NAME}
Build Number       : ${BUILD_NUMBER}
Branch Name        : ${env.GIT_BRANCH_NAME}
Commit ID          : ${env.GIT_COMMIT_ID}
Build Duration     : ${env.BUILD_DURATION}
Environment        : ${params.ENVIRONMENT}

Check console output at:
${BUILD_URL}console

-- ${BUILD_NUMBER}
""",
                to: "sagarika.mishra@vvdntech.in",
                attachLog: true,
                compressLog: true
            )
        }
    }
}
