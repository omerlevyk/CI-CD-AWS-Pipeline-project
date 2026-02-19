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
      '''
    }
  }

  environment {
    APP_IMAGE_REPO = 'omerlevyk/weather_app-app'
    NGINX_IMAGE_REPO = 'omerlevyk/weather_app-nginx'
    APP_IMAGE_LATEST = "${APP_IMAGE_REPO}:latest"
    NGINX_IMAGE_LATEST = "${NGINX_IMAGE_REPO}:latest"
  }

  stages {

    stage("EKS connectivity check") {
      steps {
        container('python') {
          sh '''
            set -x
            getent hosts 62AE89267DEAB322E7F39FBE25CE8319.gr7.us-east-1.eks.amazonaws.com || true
            wget -qO- --timeout=10 https://62AE89267DEAB322E7F39FBE25CE8319.gr7.us-east-1.eks.amazonaws.com/version || true
          '''
        }
      }
    }

    stage("Connetion Test") {
      steps {
        echo "[CONNETION TEST] Jenkinsfile found and pipeline is running"
      }
    }

    stage("Full Checkout") {
      steps {
        checkout scm
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
            sh '''
              set -eux
              mkdir -p /kaniko/.docker
              cat > /kaniko/.docker/config.json <<JSON
              {
                "auths": {
                  "https://index.docker.io/v1/": {
                    "auth": "$(printf '%s:%s' "$DH_USER" "$DH_TOKEN" | base64 | tr -d '\\n')"
                  }
                }
              }
              JSON

              /kaniko/executor \
                --context "$WORKSPACE/python_app" \
                --dockerfile "$WORKSPACE/python_app/Dockerfile" \
                --destination "$APP_IMAGE_LATEST"

              /kaniko/executor \
                --context "$WORKSPACE/nginx" \
                --dockerfile "$WORKSPACE/nginx/Dockerfile" \
                --destination "$NGINX_IMAGE_LATEST"
            '''
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
            sh '''
              set -eux
              mkdir -p /kaniko/.docker
              cat > /kaniko/.docker/config.json <<JSON
              {
                "auths": {
                  "https://index.docker.io/v1/": {
                    "auth": "$(printf '%s:%s' "$DH_USER" "$DH_TOKEN" | base64 | tr -d '\\n')"
                  }
                }
              }
JSON

              /kaniko/executor \
                --context "$WORKSPACE/python_app" \
                --dockerfile "$WORKSPACE/python_app/Dockerfile" \
                --destination "$APP_IMAGE_RELEASE"

              /kaniko/executor \
                --context "$WORKSPACE/nginx" \
                --dockerfile "$WORKSPACE/nginx/Dockerfile" \
                --destination "$NGINX_IMAGE_RELEASE"
            '''
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
            sh '''
              set -eu

              rm -rf gitops-deploy
              git clone "https://${GL_USER}:${GL_TOKEN}@gitlab.omerlevy03.com/omerlevyk/gitops.git" gitops-deploy
              cd gitops-deploy

              git config user.name "jenkins-ci"
              git config user.email "jenkins@omerlevy03.com"

              VALUES_FILE="apps/weather-stack/envs/dev-values.yaml"
              sed -i -E "s|(^[[:space:]]*tag:[[:space:]]*).*$|\\1${RELEASE_TAG}|" "${VALUES_FILE}"

              if git diff --quiet -- "${VALUES_FILE}"; then
                echo "No deploy change detected in ${VALUES_FILE}"
                exit 0
              fi

              git add "${VALUES_FILE}"
              git commit -m "ci(gitops): deploy weather image ${RELEASE_TAG} from ${JOB_NAME} #${BUILD_NUMBER}"
              git push origin main
            '''
          }
        }
      }
    }
  }

  post {
    cleanup {
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
