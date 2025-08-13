pipeline {
    agent any 

    tools {
        maven 'maven3'
    }
    
    environment {
        SCANNER_HOME = tool 'sonar-scanner'
        DOCKER_IMAGE_NAME = "gulshan126/pet-clinic2"
        DOCKER_IMAGE_TAG = "v${env.BUILD_NUMBER}"
    }
    
    stages {
        
        stage("Maven Build and test") {
            steps {
                sh "mvn clean install"
            }
        }

        stage("Sonarqube Analysis ") {
            steps {
                withSonarQubeEnv('sonar-scanner') {
                    sh ''' $SCANNER_HOME/bin/sonar-scanner -Dsonar.projectName=Petclinic1 \\
                    -Dsonar.java.binaries=. \\
                    -Dsonar.projectKey=Petclinic1 '''
                }
            }
        }
        
        stage('OWASP Dependency Check') {
            steps {
                dependencyCheck additionalArguments: '--scan target/', odcInstallation: 'owasp',prettyPrint: true
                junit allowEmptyResults: true, stdioRetention: '', testResults: 'dependency-check-junit.xml'
            }
        }
        
        stage('Publish OWASP Dependency Report') {
            steps {
                publishHTML(target: [
                    allowMissing: false,
                    alwaysLinkToLastBuild: true,
                    keepAll: true,
                    reportDir: '.',
                    reportFiles: 'dependency-check-report.html',
                    reportName: 'OWASP Dependency Check Report'
                ])
            }
        }
        
        stage("Docker Build & Push") {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'dockercred', toolName: 'docker') {
                        sh "docker build -t ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} ."
                        sh "docker push ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}"
                    }
                }
            }
        }
        
        stage("TRIVY") {
            steps {
                sh "trivy image --no-progress --format json ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} > trivy-result.json"
                archiveArtifacts artifacts: 'trivy-result.json', fingerprint: true
            }
        }

        stage('Deploy To Docker Container') {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'dockercred', toolName: 'docker') {
                        // Use the new tag for deployment
                        sh "docker run -d --name petclinic -p 8082:8080 ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}"
                    }
                }
            }
        }
        
    }
}