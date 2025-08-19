#FROM tomcat:9.0-jdk8-openjdk
#COPY target/petclinic.war /usr/local/tomcat/webapps/petclinic.war
#EXPOSE 8080
#CMD ["catalina.sh", "run"]

# ===== Stage 1: Build the WAR file =====
FROM maven:3.8.8-eclipse-temurin-8 AS build
WORKDIR /app

# Copy pom.xml and download dependencies first (cache layer)
COPY pom.xml .
RUN mvn dependency:go-offline

# Copy source code and build
COPY src ./src
RUN mvn package -DskipTests

# ===== Stage 2: Run with Tomcat =====
FROM tomcat:9.0-jdk8-temurin
WORKDIR /usr/local/tomcat/webapps/

# Remove default ROOT app if not needed
RUN rm -rf ROOT

# Copy WAR from build stage
COPY --from=build /app/target/petclinic.war ./petclinic.war

EXPOSE 8080
CMD ["catalina.sh", "run"]