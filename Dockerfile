# Build stage
FROM eclipse-temurin:17-jdk-alpine AS builder
WORKDIR /build
COPY . .
RUN ./mvnw clean package -DskipTests

# Run stage
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Add non-root user
RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring

# Copy jar from builder stage
COPY --from=builder /build/target/*.jar app.jar

# Environment variables
ENV JAVA_OPTS="-Xmx512m -Xms256m"
ENV SERVER_PORT=8080

EXPOSE ${SERVER_PORT}

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget --no-verbose --tries=1 --spider http://localhost:${SERVER_PORT}/actuator/health || exit 1

# Run the application
ENTRYPOINT ["sh", "-c", "java ${JAVA_OPTS} -jar app.jar"]
