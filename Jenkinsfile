pipeline {

```
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
        defaultValue: "${BUILD_NUMBER}",
        description: 'Docker Image Tag'
    )
}

environment {
    AWS_REGION   = "ap-south-1"
    ECR_REPO     = "ecs-app"
    ECR_REGISTRY = "706059253979.dkr.ecr.ap-south-1.amazonaws.com"
}

stages {

    stage("Build Started Notification") {
        steps {
            emailext(
                subject: "STARTED: ${JOB_NAME} #${BUILD_NUMBER}",
                body: """
```

Build Started

Job Name: ${JOB_NAME}
Build Number: ${BUILD_NUMBER}
Environment: ${params.ENVIRONMENT}

Build URL:
${BUILD_URL}
""",
to: "sagarikamishra087@gmail.com"
)
}
}

```
    stage("Build Docker Image") {
        steps {
            sh """
                docker build -t ${ECR_REPO}:${params.IMAGE_TAG} .
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
                docker tag ${ECR_REPO}:${params.IMAGE_TAG} \
                ${ECR_REGISTRY}/${ECR_REPO}:${params.IMAGE_TAG}
            """
        }
    }

    stage("Push Docker Image") {
        steps {
            sh """
                docker push ${ECR_REGISTRY}/${ECR_REPO}:${params.IMAGE_TAG}
            """
        }
    }

    stage("Deploy to EKS") {
        steps {
            sh """
                aws eks update-kubeconfig \
                    --region ${AWS_REGION} \
                    --name my-eks-cluster

                helm upgrade --install ecs-app ./ecs-app \
                    --namespace default \
                    --wait \
                    --timeout 5m \
                    --set image.repository=${ECR_REGISTRY}/${ECR_REPO} \
                    --set image.tag=${params.IMAGE_TAG}

                kubectl rollout status deployment/ecs-app \
                    -n default
            """
        }
    }
}

post {

    success {
        emailext(
            subject: "SUCCESS: ${JOB_NAME} #${BUILD_NUMBER}",
            body: """
```

Build Successful 🚀

Job Name: ${JOB_NAME}
Build Number: ${BUILD_NUMBER}
Environment: ${params.ENVIRONMENT}

Docker Image:
${ECR_REGISTRY}/${ECR_REPO}:${params.IMAGE_TAG}

Build URL:
${BUILD_URL}
""",
to: "sagarikamishra087@gmail.com"
)
}

```
    failure {
        emailext(
            subject: "FAILED: ${JOB_NAME} #${BUILD_NUMBER}",
            body: """
```

Build Failed ❌

Job Name: ${JOB_NAME}
Build Number: ${BUILD_NUMBER}
Environment: ${params.ENVIRONMENT}

Possible Failure Reasons:

* Docker build issue
* ECR authentication issue
* Docker push failure
* Helm deployment issue
* Kubernetes rollout failure

Console Logs:
${BUILD_URL}console
""",
to: "sagarikamishra087@gmail.com"
)
}
}
}
