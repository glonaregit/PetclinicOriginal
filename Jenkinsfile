pipeline {
    agent any 
    
    tools{
        maven 'maven3'
    }
    
    environment {
        SCANNER_HOME=tool 'sonar-scanner'
    }
    
    stages{
        
               
         stage("Maven Build and test"){
            steps{
                sh " mvn clean install"
            }
        }
        

               
        stage("Sonarqube Analysis "){
            steps{
                withSonarQubeEnv('sonar-scanner') {
                    sh ''' $SCANNER_HOME/bin/sonar-scanner -Dsonar.projectName=Petclinic1 \
                    -Dsonar.java.binaries=. \
                    -Dsonar.projectKey=Petclinic1 '''
    
                }
            }
        }
        
        stage('OWASP Dependency Check') {
            steps {
                dependencyCheck additionalArguments: '--scan target/', odcInstallation: 'owasp'
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
             
        stage("Docker Build & Push"){
            steps{
                script{
                   withDockerRegistry(credentialsId: 'dockercred', toolName: 'docker') {
                        
                        sh "docker build -t image1 ."
                        sh "docker tag image1 gulshan126/pet-clinic2:latest "
                        sh "docker push gulshan126/pet-clinic2:latest "
                    }
                }
            }
        }
        
        stage("TRIVY"){
            steps{
                sh " trivy image gulshan126/pet-clinic2:latest"
            }
        }

        stage('Deploy To Docker Container') {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'dockercred', toolName: 'docker') {
                        sh "docker run -d --name petclinic -p 8082:8080 gulshan126/pet-clinic2:latest"
                    }
                }
            }
        }
        
    }
}

