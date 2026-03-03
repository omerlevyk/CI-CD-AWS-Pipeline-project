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

    stage("Load Runtime Secrets") {
      steps {
        container('python') {
          sh '''
            set -eu
            ENV_FILE="$WORKSPACE/.vault_env"
            : > "$ENV_FILE"
            chmod 600 "$ENV_FILE"

            if [ -z "${VAULT_ADDR:-}" ] || [ -z "${VAULT_ROLE_ID:-}" ] || [ -z "${VAULT_SECRET_ID:-}" ]; then
              echo "Vault env vars not fully set. Using Jenkins credentials fallback."
              exit 0
            fi

            python3 - <<'PY'
import json
import os
import shlex
import sys
import urllib.request

vault_addr = os.environ.get("VAULT_ADDR", "").rstrip("/")
role_id = os.environ.get("VAULT_ROLE_ID", "")
secret_id = os.environ.get("VAULT_SECRET_ID", "")
namespace = os.environ.get("VAULT_NAMESPACE", "")
env_file = os.path.join(os.environ["WORKSPACE"], ".vault_env")

def req(method, path, payload=None, token=None):
    url = f"{vault_addr}{path}"
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    headers = {"Content-Type": "application/json"}
    if namespace:
        headers["X-Vault-Namespace"] = namespace
    if token:
        headers["X-Vault-Token"] = token
    r = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(r, timeout=20) as resp:
        return json.loads(resp.read().decode("utf-8"))

def first_value(d, keys):
    for k in keys:
        v = d.get(k)
        if v:
            return str(v)
    return ""

try:
    login = req("POST", "/v1/auth/approle/login", {"role_id": role_id, "secret_id": secret_id})
    client_token = login["auth"]["client_token"]

    dh = req("GET", "/v1/kv/data/dev/jenkins/dockerhub", token=client_token)["data"]["data"]
    gl = req("GET", "/v1/kv/data/dev/jenkins/gitlab-token", token=client_token)["data"]["data"]

    dh_user = first_value(dh, ["username", "user", "dh_user"])
    dh_token = first_value(dh, ["token", "password", "dh_token"])
    gl_user = first_value(gl, ["username", "user", "gl_user"])
    gl_token = first_value(gl, ["token", "password", "gl_token"])

    with open(env_file, "w", encoding="utf-8") as f:
        if dh_user:
            f.write(f"export VAULT_DH_USER={shlex.quote(dh_user)}\\n")
        if dh_token:
            f.write(f"export VAULT_DH_TOKEN={shlex.quote(dh_token)}\\n")
        if gl_user:
            f.write(f"export VAULT_GL_USER={shlex.quote(gl_user)}\\n")
        if gl_token:
            f.write(f"export VAULT_GL_TOKEN={shlex.quote(gl_token)}\\n")

    print("Loaded runtime secrets from Vault.")
except Exception as exc:
    print(f"Vault fetch failed, using Jenkins credentials fallback: {exc}")
    with open(env_file, "w", encoding="utf-8") as f:
        f.write("")
    sys.exit(0)
PY
          '''
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
              if [ -f "$WORKSPACE/.vault_env" ]; then . "$WORKSPACE/.vault_env"; fi
              if [ -n "${VAULT_DH_USER:-}" ] && [ -n "${VAULT_DH_TOKEN:-}" ]; then
                DH_USER="$VAULT_DH_USER"
                DH_TOKEN="$VAULT_DH_TOKEN"
                echo "Using Vault runtime DockerHub credentials"
              else
                echo "Using Jenkins credential store for DockerHub"
              fi

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
              if [ -f "$WORKSPACE/.vault_env" ]; then . "$WORKSPACE/.vault_env"; fi
              if [ -n "${VAULT_DH_USER:-}" ] && [ -n "${VAULT_DH_TOKEN:-}" ]; then
                DH_USER="$VAULT_DH_USER"
                DH_TOKEN="$VAULT_DH_TOKEN"
                echo "Using Vault runtime DockerHub credentials"
              else
                echo "Using Jenkins credential store for DockerHub"
              fi

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
              if [ -f "$WORKSPACE/.vault_env" ]; then . "$WORKSPACE/.vault_env"; fi
              if [ -n "${VAULT_GL_USER:-}" ] && [ -n "${VAULT_GL_TOKEN:-}" ]; then
                GL_USER="$VAULT_GL_USER"
                GL_TOKEN="$VAULT_GL_TOKEN"
                echo "Using Vault runtime GitLab credentials"
              else
                echo "Using Jenkins credential store for GitLab"
              fi

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
              git push origin HEAD:dev
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
