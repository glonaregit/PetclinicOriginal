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
        CONTAINER_PORT = "8082"
        INTERNAL_APP_PORT = "8080"
        MANIFEST_REPO = "https://github.com/glonaregit/kubernetes.git"
        MANIFEST_BRANCH = "main"  // or another branch
        MANIFEST_DIR = "manifests"


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

        stage('Delete docker container using shell script'){
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'ubntuvm_cred', usernameVariable: 'SSH_USER', passwordVariable: 'SSH_PASS')]) {
                            sh "bash delete_docker_container.sh"
                    }
                }
            }
            
        }

        stage('Deploy To Docker Container on Azure VM') {
            when {
                branch 'feature/*'
            }
            steps {
                script {
                    withCredentials([
                        usernamePassword(credentialsId: 'ubntuvm_cred', usernameVariable: 'SSH_USER', passwordVariable: 'SSH_PASS'),
                        usernamePassword(credentialsId: 'dockercred', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')
                    ]) {
                        sh "bash deploy_docker_container.sh"
                    }
                }
            }
        }

        // stage('Create DockerHub Pull Secret in Kubernetes') {
        //     steps {
        //         withCredentials([
        //             file(credentialsId: 'aks-kubeconfig', variable: 'KUBECONFIG_FILE'),
        //             usernamePassword(credentialsId: 'dockercred', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')
        //         ]) {
        //             sh '''

        //                 mkdir -p ~/.kube
        //                 cp $KUBECONFIG_FILE ~/.kube/config

        //                 kubectl create secret docker-registry dockercred \
        //                 --docker-username=$DOCKER_USER \
        //                 --docker-password=$DOCKER_PASS \
        //                 --docker-email=admin@example.com \
        //                 --namespace=default \
        //                 --dry-run=client -o yaml | kubectl apply -f -
        //             '''
        //         }
        //     }
        // }

        stage('Create DockerHub Pull Secret in Kubernetes') {
    steps {
        withCredentials([
            azureServicePrincipal(credentialsId: 'Azure_sp'),
            usernamePassword(credentialsId: 'dockercred', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')
        ]) {
            sh '''
                echo "Logging into Azure..."
                az login --service-principal \
                    -u $AZURE_CLIENT_ID \
                    -p $AZURE_CLIENT_SECRET \
                    --tenant $AZURE_TENANT_ID

                # (Optional) set subscription explicitly
                az account set --subscription $AZURE_SUBSCRIPTION_ID || true

                echo "Getting AKS credentials into a temp kubeconfig..."
                export KUBECONFIG=$WORKSPACE/kubeconfig
                echo "Getting AKS credentials..."
                az aks get-credentials --resource-group devopsrg --name aksjenkin --overwrite-existing

                echo "Creating DockerHub secret in AKS..."
                kubectl --kubeconfig=$KUBECONFIG create secret docker-registry dockercred \
                --docker-username=$DOCKER_USER \
                --docker-password=$DOCKER_PASS \
                --docker-email=admin@example.com \
                --namespace=default \
                --dry-run=client -o yaml | kubectl apply --kubeconfig=$KUBECONFIG -f -
            '''
        }
    }
}


        stage('deploy to K8s') {
            steps{
                // when {
                //         branch 'main'
                //     }

                        withCredentials([
                            file(credentialsId: 'aks-kubeconfig', variable: 'KUBECONFIG_PATH')
                        ]) {
                            sh '''
                                export KUBECONFIG=$KUBECONFIG_PATH

                                # Clone the manifest repo
                                git clone --branch $MANIFEST_BRANCH $MANIFEST_REPO $MANIFEST_DIR

                                # Optionally, dynamically update image tag in manifest (if needed)
                                sed -i "s#image: .*#image: gulshan126/pet-clinic2:v$BUILD_NUMBER#g" $MANIFEST_DIR/deployment.yml

                                # Deploy to AKS
                                kubectl apply -f $MANIFEST_DIR/deployment.yml
                            '''

                        }
            }
        }
       
    }
}