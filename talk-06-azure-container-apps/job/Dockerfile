# syntax=docker/dockerfile:1
# Stage 1: Build
FROM maven:3.9.9-eclipse-temurin-21 AS build

WORKDIR /app

# --- Corporate CA trust (e.g. Netskope TLS interception) ---------------------
# Supply a corporate CA cert as a BuildKit secret — the cert is not stored in any image layer:
#   docker build --secret id=netskope_cert,src=certs/netskope.crt -t myapp .
# Omit --secret when not behind a proxy; the cert guard in each network RUN is a no-op.
# -----------------------------------------------------------------------------

# Copy Maven wrapper and POM
COPY job/pom.xml ./
COPY job/src ./src

# Download dependencies and build
RUN --mount=type=cache,target=/root/.m2 \
    --mount=type=secret,id=netskope_cert <<'EOF'
set -e
if [ -s /run/secrets/netskope_cert ]; then
  keytool -importcert -noprompt -alias netskope -file /run/secrets/netskope_cert -cacerts -storepass changeit
fi
mvn dependency:go-offline -B
mvn package -DskipTests -B
if [ -s /run/secrets/netskope_cert ]; then
  keytool -delete -alias netskope -cacerts -storepass changeit
fi
EOF

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
