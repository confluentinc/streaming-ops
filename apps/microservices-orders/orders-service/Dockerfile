FROM openjdk:11-jdk-slim
WORKDIR /app
ARG JAR_FILE=build/libs/*.jar
COPY ${JAR_FILE} .
COPY start.sh .
ENTRYPOINT [ "/app/start.sh" ]
