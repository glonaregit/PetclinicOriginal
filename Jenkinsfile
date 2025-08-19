pipeline {
    agent any 

    tools {
        maven 'maven3'
    }

    environment {
        SCANNER_HOME    = tool 'sonar-scanner'
        DOCKER_IMAGE_NAME = "gulshan126/pet-clinic2"
        DOCKER_IMAGE_TAG  = "v${env.BUILD_NUMBER}"
        VM_HOST         = '74.249.249.219'
        CONTAINER_PORT  = "8082"
        INTERNAL_APP_PORT = "8080"
        MANIFEST_REPO   = "https://github.com/glonaregit/kubernetes.git"
        MANIFEST_DIR    = "manifests"
    }

    stages {
        /* -------------------------
         *  CONTINUOUS INTEGRATION
         * ------------------------- */
        stage("Build & Unit Tests") {
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

        stage("OWASP Dependency Check") {
            steps {
                dependencyCheck additionalArguments: '''
                    --scan 'target/' 
                    --out './'  
                    --format 'ALL' 
                    --disableYarnAudit \
                    --prettyPrint
                ''', odcInstallation: 'owasp'
            }
        }

        stage("Publish OWASP Dependency Report") {
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

        stage("Trivy Image Scan") {
            steps {
                   sh """
                # JSON output (for archiving)
                trivy image --no-progress --format json -o trivy-result.json ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}
                # HTML output (for human-readable report)
                trivy image --no-progress --format template --template "@ci/templates/html.tpl" -o trivy-report.html ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}

                ls -lh trivy-result.json trivy-report.html
                """
                archiveArtifacts artifacts: 'trivy-result.json', fingerprint: true

                publishHTML(target: [allowMissing: false, alwaysLinkToLastBuild: true, keepAll: true, reportDir: '.', reportFiles: 'trivy-report.html', reportName: 'Trivy Image Scan Report'])
            }
        }

        /* -------------------------
         *  CONTINUOUS DELIVERY
         * ------------------------- */
        stage("Docker Push") {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'dockercred', toolName: 'docker') {
                        sh "docker push ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}"
                    }
                }
            }
        }

        stage("Create DockerHub Pull Secret in AKS") {
            steps {
                withCredentials([
                    azureServicePrincipal(credentialsId: 'Azure_sp'),
                    usernamePassword(credentialsId: 'dockercred', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')
                ]) {
                    sh '''
                        az login --service-principal \
                            -u $AZURE_CLIENT_ID \
                            -p $AZURE_CLIENT_SECRET \
                            --tenant $AZURE_TENANT_ID
                        az account set --subscription $AZURE_SUBSCRIPTION_ID || true
                        export KUBECONFIG=$WORKSPACE/kubeconfig
                        az aks get-credentials --resource-group devopsrg --name aksjenkin --file $KUBECONFIG --overwrite-existing

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

        /* -------------------------
         *  CONTINUOUS DEPLOYMENT
         * ------------------------- */
        stage("Deploy to Test VM (Feature Branches)") {
            when { branch pattern: "feature/.*", comparator: "REGEXP" }
            steps {
                script {
                    withCredentials([
                        usernamePassword(credentialsId: 'ubntuvm_cred', usernameVariable: 'SSH_USER', passwordVariable: 'SSH_PASS'),
                        usernamePassword(credentialsId: 'dockercred', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')
                    ]) {
                        sh "bash delete_docker_container.sh"
                        sh "bash deploy_docker_container.sh"
                    }
                }
            }
        }

        stage("Deploy to Staging AKS (Develop Branch)") {
            when { branch 'develop' }
            steps {
                script {
                    withCredentials([azureServicePrincipal(credentialsId: 'Azure_sp')]) {
                        sh '''
                            az login --service-principal \
                                -u $AZURE_CLIENT_ID \
                                -p $AZURE_CLIENT_SECRET \
                                --tenant $AZURE_TENANT_ID
                            az account set --subscription $AZURE_SUBSCRIPTION_ID || true
                            export KUBECONFIG=$WORKSPACE/kubeconfig
                            az aks get-credentials --resource-group devopsrg --name aksjenkin --file $KUBECONFIG --overwrite-existing

                            rm -rf $MANIFEST_DIR
                            git clone --branch main $MANIFEST_REPO $MANIFEST_DIR
                            sed -i "s#image: .*#image: ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}#g" $MANIFEST_DIR/deployment.yml
                            kubectl --kubeconfig=$KUBECONFIG apply -f $MANIFEST_DIR/deployment.yml
                        '''
                    }
                }
            }
        }

        stage("Deploy to Prod AKS (Main Branch)") {
            when { branch 'main' }
            steps {
                script {
                    withCredentials([azureServicePrincipal(credentialsId: 'Azure_sp')]) {
                        sh '''
                            az login --service-principal \
                                -u $AZURE_CLIENT_ID \
                                -p $AZURE_CLIENT_SECRET \
                                --tenant $AZURE_TENANT_ID
                            az account set --subscription $AZURE_SUBSCRIPTION_ID || true
                            export KUBECONFIG=$WORKSPACE/kubeconfig
                            az aks get-credentials --resource-group devopsrg --name aksjenkin --file $KUBECONFIG --overwrite-existing

                            rm -rf $MANIFEST_DIR
                            git clone --branch main $MANIFEST_REPO $MANIFEST_DIR
                            sed -i "s#image: .*#image: ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}#g" $MANIFEST_DIR/deployment.yml
                            kubectl --kubeconfig=$KUBECONFIG apply -f $MANIFEST_DIR/deployment.yml
                        '''
                    }
                }
            }
        }
    }
}
