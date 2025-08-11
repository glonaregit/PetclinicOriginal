pipeline {
    agent any 
    
    tools{
        maven 'maven3'
    }
    
    environment {
        SCANNER_HOME=tool 'sonar-scanner'
    }
    
    stages{
        
               
        stage("Compile"){
            steps{
                sh "mvn clean compile"
            }
        }
        
         stage("Test Cases"){
            steps{
                sh "mvn test"
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
        
            stage("Build"){
            steps{
                sh " mvn clean install"
            }
        }
        
              
        
    }
}
