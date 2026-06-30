# Stage 1: Build
FROM maven:3.9.9-eclipse-temurin-21 AS build

WORKDIR /app

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

# Copy Maven wrapper and POM
COPY job/pom.xml ./

# Download dependencies (cached layer)
RUN --mount=type=cache,target=/root/.m2 \
    mvn dependency:go-offline -B

# Copy source and build
COPY job/src ./src
RUN --mount=type=cache,target=/root/.m2 \
    mvn package -DskipTests -B

# Stage 2: Runtime
FROM eclipse-temurin:21-jre AS runtime

WORKDIR /app

# Create non-root user
RUN groupadd --system appgroup && useradd --system --gid appgroup --home-dir /app --shell /usr/sbin/nologin appuser

# Copy built jar
COPY --from=build /app/target/*.jar app.jar
RUN chown appuser:appgroup /app/app.jar

USER appuser

# Jobs don't need EXPOSE (no incoming traffic)
# They run to completion and exit

ENV JAVA_OPTS="-Xms64m -Xmx256m"

CMD ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
