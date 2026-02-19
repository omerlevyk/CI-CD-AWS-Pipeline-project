pipeline {
  agent { label 'k8s-dynamic' }

  stages {
    stage('test agent') {
      steps {
        sh 'echo HELLO FROM K8S'
        sh 'hostname'
        sh 'cat /etc/hostname'
        sh 'ip a || true'
        sh 'env | sort | rg -i "jenkins|kubernetes|node|pod" || true'
      }
    }
  }
}
