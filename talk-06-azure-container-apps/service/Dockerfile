FROM eclipse-temurin:21-jdk-alpine AS build
WORKDIR /workspace
RUN apk add --no-cache maven
COPY pom.xml ./
COPY src ./src
RUN mvn -q -DskipTests package

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
RUN addgroup -S spring && adduser -S spring -G spring
COPY --from=build /workspace/target/*.jar app.jar
USER spring
EXPOSE 8080
CMD ["java", "-jar", "/app/app.jar"]
