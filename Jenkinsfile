pipeline {
    agent any 

    tools {
        maven 'maven3'
    }
    
    environment {
        SCANNER_HOME = tool 'sonar-scanner'
        DOCKER_IMAGE_NAME = "gulshan126/pet-clinic2"
        DOCKER_IMAGE_TAG = "v${env.BUILD_NUMBER}"
        VM_HOST = '74.249.249.219'

    }
    
    stages {
        
        stage("Maven Build and Test") {
            steps {
                sh "mvn clean install"
            }
        }

        stage("SonarQube Analysis") {
            steps {
                withSonarQubeEnv('sonar-scanner') {
                    sh '''
                        $SCANNER_HOME/bin/sonar-scanner \
                        -Dsonar.projectName=Petclinic1 \
                        -Dsonar.java.binaries=. \
                        -Dsonar.projectKey=Petclinic1
                    '''
                }
                    waitForQualityGate abortPipeline: true
            }
        }
        
        stage('OWASP Dependency Check') {
            steps {
                dependencyCheck additionalArguments: '''
                    --scan 'target/' 
                    --out './'  
                    --format 'ALL' 
                    --disableYarnAudit \
                    --prettyPrint
                ''', odcInstallation: 'owasp'
                //junit allowEmptyResults: true, stdioRetention: '', testResults: 'dependency-check-junit.xml'
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
        
        stage("Docker Build") {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'dockercred', toolName: 'docker') {
                        sh "docker build -t ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} ."
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

        stage("Docker Push") {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'dockercred', toolName: 'docker') {
                        sh "docker push ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}"
                    }
                }
            }
        }

        // stage('Deploy To Docker Container') {
        //     steps {
        //         script {
        //             withDockerRegistry(credentialsId: 'dockercred', toolName: 'docker') {
        //                 def containerPort = "8082"
        //                 def newContainerName = "petclinic-${DOCKER_IMAGE_TAG}"

        //                 // Check for a running container on the same host port
        //                 def existingContainerId = sh(
        //                     script: "docker ps -q --filter 'publish=${containerPort}'", 
        //                     returnStdout: true
        //                 ).trim()

        //                 if (existingContainerId) {
        //                     echo "Stopping and removing existing container on port ${containerPort} with ID: ${existingContainerId}"
        //                     sh "docker stop ${existingContainerId}"
        //                     sh "docker rm ${existingContainerId}"
        //                 }

        //                 // Deploy the new container
        //                 sh "docker run -d --name ${newContainerName} -p ${containerPort}:8080 ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}"
        //             }
        //         }
        //     }
        // }

        // 
       stage('Delete Docker Container') {
    steps {
        script {
            def containerPort = "8082"
            
            withCredentials([usernamePassword(credentialsId: 'ubntuvm_cred', usernameVariable: 'SSH_USER', passwordVariable: 'SSH_PASS')]) {
                withEnv(["SSHPASS=${SSH_PASS}"]) {
                    sh """
                    sshpass -e ssh -o StrictHostKeyChecking=no \$SSH_USER@\$VM_HOST <<'END_SCRIPT'
                        
                        echo "Checking for existing container on port ${containerPort}..."
                        
                        EXISTING_CONTAINER_ID=\$(sudo docker ps -q --filter "publish=${containerPort}")
                        
                        if [ -n "\$EXISTING_CONTAINER_ID" ]; then
                            echo "Stopping and removing existing container on port ${containerPort} with ID: \$EXISTING_CONTAINER_ID"
                            sudo docker stop \$EXISTING_CONTAINER_ID
                            sudo docker rm \$EXISTING_CONTAINER_ID
                        else
                            echo "No existing container found on port ${containerPort}."
                        fi
                    END_SCRIPT
                    """
                }
            }
        }
    }
}

        stage('Deploy To Docker Container on Azure VM') {
            steps {
                script {
                    def containerPort = "8082"
                    def internalAppPort = "8080"
                    def newContainerName = "petclinic-${DOCKER_IMAGE_TAG}"
                    def imageNameWithTag = "${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}"

                    withDockerRegistry(credentialsId: 'dockercred', toolName: 'docker') {
                        withCredentials([usernamePassword(credentialsId: 'ubntuvm_cred', usernameVariable: 'SSH_USER', passwordVariable: 'SSH_PASS')]) {
                            withCredentials([usernamePassword(credentialsId: 'dockercred', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                                sh """
                                sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no $SSH_USER@$VM_HOST <<'EOF'
                                    echo "Logging in to Docker Hub..."
                                    echo "$DOCKER_PASS" | sudo docker login -u "$DOCKER_USER" --password-stdin

                                    echo "Pulling latest Docker image: ${imageNameWithTag}"
                                    sudo docker pull ${imageNameWithTag}

                                    echo "Running new container: ${newContainerName}"
                                    sudo docker run -d --name ${newContainerName} -p ${containerPort}:${internalAppPort} ${imageNameWithTag}
                                EOF
                                """
                            }
                        }
                    }
                }
            }
        }

        
    }
}