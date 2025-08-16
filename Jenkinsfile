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

        stage('Deploy To Docker Container on Azure VM') {
            steps {
                script {
                    def containerPort = "8082"
                    def newContainerName = "petclinic-${DOCKER_IMAGE_TAG}"
                    def internalAppPort = "8080"

                    withCredentials([usernamePassword(credentialsId: 'azure-vm-login', usernameVariable: 'SSH_USER', passwordVariable: 'SSH_PASS')]) {
                        withDockerRegistry(credentialsId: 'dockercred', toolName: 'docker') {

                            sh """
                                sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no \$SSH_USER@${VM_HOST} << EOF

                                    echo "Pulling latest Docker image: ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}"
                                    docker pull ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}

                                    echo "Checking for existing container on port ${containerPort}..."
                                    existing_container=\$(docker ps -q --filter "publish=${containerPort}")
                                    if [ ! -z "\$existing_container" ]; then
                                        echo "Stopping and removing existing container with ID: \$existing_container"
                                        docker stop \$existing_container
                                        docker rm \$existing_container
                                    fi

                                    echo "Running new container: ${newContainerName}"
                                    docker run -d --name ${newContainerName} -p ${containerPort}:${internalAppPort} ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}
                                EOF
                            """
                        }
                    }
                }
            }
        }


    }
}