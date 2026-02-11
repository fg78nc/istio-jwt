ARG DOCKER_REGISTRY=""
FROM ${DOCKER_REGISTRY}eclipse-temurin:17-jre-jammy

WORKDIR /app

COPY target/istio-jwt-1.0-SNAPSHOT.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
