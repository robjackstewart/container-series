FROM gradle:8.5-jdk21 AS build
WORKDIR /home/gradle/src
COPY build.gradle.kts settings.gradle.kts ./
COPY src ./src
RUN gradle --no-daemon shadowJar

FROM eclipse-temurin:21-jre-alpine
RUN addgroup -S app && adduser -S app -G app
WORKDIR /app
COPY --from=build /home/gradle/src/build/libs/app.jar /app/app.jar
ENV PORT=8080
EXPOSE 8080
USER app
CMD ["java", "-jar", "/app/app.jar"]
