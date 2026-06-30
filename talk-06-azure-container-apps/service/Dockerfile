FROM maven:3.9.9-eclipse-temurin-21 AS build

WORKDIR /workspace

# --- Corporate CA trust (e.g. Netskope TLS interception) ---------------------
# Default EXTRA_CERTS_DIR=certs points at an empty placeholder, so this is a NO-OP
# on a normal laptop and only activates when real .crt files are supplied in certs/.
# Pass real certs with:  docker build --build-arg EXTRA_CERTS_DIR=certs ...
ARG EXTRA_CERTS_DIR=certs
COPY ${EXTRA_CERTS_DIR}/ /usr/local/share/ca-certificates/extra/
RUN if ls -A /usr/local/share/ca-certificates/extra/ 2>/dev/null | grep -q .; then \
        if command -v update-ca-certificates >/dev/null 2>&1; then \
            update-ca-certificates; \
        else \
            cat /usr/local/share/ca-certificates/extra/*.crt >> /etc/ssl/certs/ca-certificates.crt; \
        fi; \
    fi
# -----------------------------------------------------------------------------

COPY service/pom.xml ./
RUN --mount=type=cache,target=/root/.m2 \
    mvn dependency:go-offline -B

COPY service/src ./src
RUN --mount=type=cache,target=/root/.m2 \
    mvn package -DskipTests -B

FROM eclipse-temurin:21-jre
WORKDIR /app
RUN groupadd --system spring && useradd --system --gid spring --home-dir /app --shell /usr/sbin/nologin spring
COPY --from=build /workspace/target/*.jar app.jar
RUN chown spring:spring /app/app.jar
USER spring
EXPOSE 8080
ENV JAVA_OPTS="-Xms128m -Xmx512m"
CMD ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]
