FROM eclipse-temurin:17-jdk-alpine

EXPOSE ${SERVER_PORT}

RUN ls

ENV APP_HOME=/usr/src/app

# Environment variables
ENV JAVA_OPTS="-Xmx512m -Xms256m"
ENV SERVER_PORT=8080

COPY target/*.jar $APP_HOME/app.jar

WORKDIR $APP_HOME

CMD ["java", "-jar", "app.jar"]
