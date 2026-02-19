pipeline {
  agent any

  stages {

    stage("EKS connectivity check") {
      steps {
        sh '''
          set -x
          getent hosts 62AE89267DEAB322E7F39FBE25CE8319.gr7.us-east-1.eks.amazonaws.com || true
          curl -vk --max-time 10 https://62AE89267DEAB322E7F39FBE25CE8319.gr7.us-east-1.eks.amazonaws.com/version || true
        '''
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
        sh '''
          python3 -m venv venv
          . venv/bin/activate
          pip install --upgrade pip
          pip install -r python_app/requirements.txt
          pip install pylint
        '''
      }
    }

    stage("Pylint") {
      steps {
        sh '''
        . venv/bin/activate
        pylint --fail-under=7 python_app/
        '''
      }
    }
    
    stage("Build Docker Images") {
        steps {
            sh '''
            docker build -t registry.gitlab.com/omerlevyk/weather_app/app:latest python_app
            docker build -t registry.gitlab.com/omerlevyk/weather_app/nginx:latest nginx
            '''
          }
      }

    stage('Tag Images') {
      steps {
        sh '''
        docker tag registry.gitlab.com/omerlevyk/weather_app/app:latest omerlevyk/weather_app-app:latest
        docker tag registry.gitlab.com/omerlevyk/weather_app/nginx:latest omerlevyk/weather_app-nginx:latest
        '''
      }
    }

    stage('Push Images') {
      steps {
        withCredentials([
          usernamePassword(
            credentialsId: 'dockerhub',
            usernameVariable: 'DH_USER',
            passwordVariable: 'DH_TOKEN'
          )
        ]) {
            sh '''
            echo "$DH_TOKEN" | docker login -u "$DH_USER" --password-stdin

            docker push omerlevyk/weather_app-app:latest
            docker push omerlevyk/weather_app-nginx:latest
            '''
        }
      }
    }

    stage("Deploy") {
      when {
        branch 'main'
      }
      steps {
        sshagent(['weather-app-ssh']) {
          sh """
            ssh -o StrictHostKeyChecking=no ubuntu@54.236.39.199 '
              cd /opt/weather_app &&
              docker-compose pull &&
              docker-compose up -d
            '
          """
        }
      }
    }
  }

  post {
    success {
      slackSend(
        channel: '#all-pythonapp',
        color: 'good',
        message: """
          *DEPLOY SUCCESSFUL*

          *Project:* ${env.JOB_NAME}
          *Build:* #${env.BUILD_NUMBER}

          https://youtu.be/dQw4w9WgXcQ?si=8TXKNgFDvph6W53m
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
