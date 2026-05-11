# Stage 1: Build
FROM eclipse-temurin:21-jdk-alpine AS build

WORKDIR /app

# Copy Maven wrapper and POM
COPY pom.xml ./

# Download dependencies (cached layer)
RUN --mount=type=cache,target=/root/.m2 \
    mvn dependency:go-offline -B 2>/dev/null || true

# Copy source and build
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 \
    mvn package -DskipTests -B

# Stage 2: Runtime
FROM eclipse-temurin:21-jre-alpine AS runtime

WORKDIR /app

# Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy built jar
COPY --from=build /app/target/*.jar app.jar

USER appuser

# Jobs don't need EXPOSE (no incoming traffic)
# They run to completion and exit

ENV JAVA_OPTS="-Xms64m -Xmx256m"

CMD ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
