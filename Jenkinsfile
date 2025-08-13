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
                //dependencyCheck additionalArguments: '--scan target/', odcInstallation: 'owasp',prettyPrint: true
                dependencyCheck additionalArguments: '--scan target/', odcInstallation: 'owasp', prettyPrint: true
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
                def containerPort = "8082"
                def newContainerName = "petclinic-${DOCKER_IMAGE_TAG}"

                // Check for a running container on the same host port
                def existingContainerId = sh(script: "docker ps -q --filter 'publish=${containerPort}'", returnStdout: true).trim()

                if (existingContainerId) {
                    echo "Stopping and removing existing container on port ${containerPort} with ID: ${existingContainerId}"
                    sh "docker stop ${existingContainerId}"
                    sh "docker rm ${existingContainerId}"
                }

                // Deploy the new container
                sh "docker run -d --name ${newContainerName} -p ${containerPort}:8080 ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}"
            }
        }
            }
        }
        
    }
}