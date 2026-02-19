pipeline {
  agent {
    kubernetes {
      cloud 'kubernetes'
      defaultContainer 'shell'
      yaml '''
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: jenkins-agent-test
spec:
  serviceAccountName: jenkins-k8s
  containers:
  - name: shell
    image: alpine:3.20
    command:
    - cat
    tty: true
'''
    }
  }

  stages {
    stage('k8s agent test') {
      steps {
        sh 'echo HELLO FROM K8S'
        sh 'hostname'
        sh 'cat /etc/hostname'
      }
    }
  }
}
