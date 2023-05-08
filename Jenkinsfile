pipeline {
  options {
    disableConcurrentBuilds()
  }
  agent {
    kubernetes{
      yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: node
    image: node:18.15
    tty: true
    command: ['cat']
"""
    }
  }
  stages {
    stage('Build') {
      steps {
        container(name: 'node') {
          withCredentials([string(credentialsId: 'jenkins-codecov-tokens', variable: 'CODECOV_TOKEN')]) {
            sh 'git config --global --add safe.directory \'*\''
            sh 'cp .env-example .env'
            sh 'npm install'
            sh 'npm test'
            sh "npm run coverage"
            sh 'cat ./coverage.json'
            sh "./node_modules/.bin/codecov"
          }
        }
      }
    }
  }
}
