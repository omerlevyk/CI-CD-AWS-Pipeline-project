pipeline {
  agent {
    kubernetes {
      defaultContainer 'python'
      yaml '''
        apiVersion: v1
        kind: Pod
        metadata:
          labels:
            app: weather-ci
        spec:
          serviceAccountName: jenkins-k8s
          containers:
          - name: python
            image: python:3.11-alpine
            command: ["cat"]
            tty: true
          - name: kaniko
            image: gcr.io/kaniko-project/executor:v1.23.2-debug
            command: ["cat"]
            tty: true
          - name: gitleaks
            image: zricethezav/gitleaks:v8.24.2
            command: ["sh", "-c", "cat"]
            tty: true
          - name: trivy
            image: aquasec/trivy:0.57.1
            command: ["sh", "-c", "cat"]
            tty: true
          - name: cosign
            image: bitnami/cosign:2.4.1
            command: ["sh", "-c", "cat"]
            tty: true
      '''
    }
  }

  environment {
    APP_IMAGE_REPO = 'omerlevyk/weather_app-app'
    NGINX_IMAGE_REPO = 'omerlevyk/weather_app-nginx'
    APP_IMAGE_LATEST = "${APP_IMAGE_REPO}:latest"
    NGINX_IMAGE_LATEST = "${NGINX_IMAGE_REPO}:latest"
    EKS_API_ENDPOINT = 'BC56FC1FAC7BA3C30783B8DF1A246F09.yl4.us-east-1.eks.amazonaws.com'
  }

  stages {

    stage("EKS connectivity check") {
      steps {
        container('python') {
          sh '''
            set -x
            getent hosts "${EKS_API_ENDPOINT}" || true
            wget -qO- --timeout=10 "https://${EKS_API_ENDPOINT}/version" || true
          '''
        }
        echo "[CONNETION TEST] Jenkinsfile found and pipeline is running"
      }
    }

    stage("Full Checkout") {
      steps {
        checkout scm
      }
    }

    stage("Secret Scan (Git)") {
      steps {
        container('gitleaks') {
          sh '''
            set -x
            gitleaks detect --source . --redact --no-banner --exit-code 1
          '''
        }
      }
    }

    stage("Load Runtime Secrets") {
      steps {
        container('python') {
          sh 'bash scripts/ci/load_runtime_secrets.sh'
        }
      }
    }

    stage("Setup venv") {
      steps {
        container('python') {
          sh '''
            set -eux
            python3 -m venv venv
            . venv/bin/activate
            pip install --upgrade pip
            pip install -r python_app/requirements.txt
            pip install pylint
            pip install bandit
          '''
        }
      }
    }

    stage("Pylint") {
      steps {
        container('python') {
          sh '''
            set -eux
            . venv/bin/activate
            pylint --fail-under=7.5 python_app/
          '''
        }
      }
    }

    stage("Static Analysis (main only)") {
      when {
        branch 'main'
      }
      steps {
        container('python') {
          sh '''
            set -eux
            . venv/bin/activate
            bandit -r python_app -ll -iii
          '''
        }
      }
    }

    stage("Dependency Scan (Critical threshold)") {
      steps {
        container('trivy') {
          sh '''
            set -eux
            trivy fs --scanners vuln --severity CRITICAL \
              --exit-code 1 --no-progress python_app
          '''
        }
      }
    }

    stage("Dockerfile Scan") {
      steps {
        container('trivy') {
          sh '''
            set -eux
            trivy config --severity HIGH,CRITICAL \
              --exit-code 1 --no-progress \
              python_app/Dockerfile nginx/Dockerfile
          '''
        }
      }
    }

    stage("Build Docker Images") {
      steps {
        container('kaniko') {
          withCredentials([
            usernamePassword(
              credentialsId: 'dockerhub',
              usernameVariable: 'DH_USER',
              passwordVariable: 'DH_TOKEN'
            )
          ]) {
            sh 'bash scripts/ci/build_images_latest.sh'
          }
        }
      }
    }

    stage('Tag Images') {
      steps {
        script {
          env.RELEASE_TAG = "v1.0.${env.BUILD_NUMBER}-${new Date().format('yyyyMMdd-HHmmss', TimeZone.getTimeZone('UTC'))}"
          env.APP_IMAGE_RELEASE = "${APP_IMAGE_REPO}:${env.RELEASE_TAG}"
          env.NGINX_IMAGE_RELEASE = "${NGINX_IMAGE_REPO}:${env.RELEASE_TAG}"
          echo "Prepared tags: ${env.APP_IMAGE_RELEASE}, ${env.NGINX_IMAGE_RELEASE}"
        }
      }
    }

    stage('Push Images') {
      steps {
        container('kaniko') {
          withCredentials([
            usernamePassword(
              credentialsId: 'dockerhub',
              usernameVariable: 'DH_USER',
              passwordVariable: 'DH_TOKEN'
            )
          ]) {
            sh 'bash scripts/ci/push_images_release.sh'
          }
        }
      }
    }

    stage("Sign Container Images") {
      when {
        branch 'main'
      }
      steps {
        container('cosign') {
          withCredentials([
            usernamePassword(
              credentialsId: 'dockerhub',
              usernameVariable: 'DH_USER',
              passwordVariable: 'DH_TOKEN'
            ),
            file(credentialsId: 'cosign-private-key', variable: 'COSIGN_PRIVATE_KEY_FILE'),
            string(credentialsId: 'cosign-password', variable: 'COSIGN_PASSWORD')
          ]) {
            sh 'bash scripts/ci/sign_images.sh'
          }
        }
      }
    }

    stage("Deploy") {
      steps {
        container('jnlp') {
          withCredentials([
            usernamePassword(
              credentialsId: 'gitlab-token',
              usernameVariable: 'GL_USER',
              passwordVariable: 'GL_TOKEN'
            )
          ]) {
            sh 'bash scripts/ci/deploy_gitops.sh'
          }
        }
      }
    }
  }

  post {
    cleanup {
      container('python') {
        sh '''
          set +e
          chmod -R a+rwX "$WORKSPACE" 2>/dev/null
        '''
      }
      deleteDir()
      echo "[CLEAN] workspase directory hes been deleted"
    }

    success {
      slackSend(
        channel: '#all-pythonapp',
        color: 'good',
        message: """
          *DEPLOY SUCCESSFUL*

          *Project:* ${env.JOB_NAME}
          *Build:* #${env.BUILD_NUMBER}
        """
      )
    }

    failure {
      slackSend(
        channel: '#all-pythonapp',
        color: 'danger',
        message: """
          *BUILD FAILED*

          *Project:* ${env.JOB_NAME}
          *Build:* #${env.BUILD_NUMBER}

          Check Jenkins logs for details
        """
      )
    }
  }
}
