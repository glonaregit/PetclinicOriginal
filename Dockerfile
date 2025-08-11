FROM tomcat:9.0-jdk8-openjdk
COPY target/petclinic.war /usr/local/tomcat/webapps/petclinic.war
EXPOSE 8082
CMD ["catalina.sh", "run"]