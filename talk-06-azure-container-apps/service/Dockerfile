# syntax=docker/dockerfile:1
FROM maven:3.9.9-eclipse-temurin-21 AS build

WORKDIR /workspace

# --- Corporate CA trust (e.g. Netskope TLS interception) ---------------------
# Supply a corporate CA cert as a BuildKit secret — the cert is not stored in any image layer:
#   docker build --secret id=netskope_cert,src=certs/netskope.crt -t myapp .
# Omit --secret when not behind a proxy; the cert guard in each network RUN is a no-op.
# -----------------------------------------------------------------------------

COPY service/pom.xml ./
COPY service/src ./src
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

FROM eclipse-temurin:21-jre
WORKDIR /app
RUN groupadd --system spring && useradd --system --gid spring --home-dir /app --shell /usr/sbin/nologin spring
COPY --from=build /workspace/target/*.jar app.jar
RUN chown spring:spring /app/app.jar
USER spring
EXPOSE 8080
ENV JAVA_OPTS="-Xms128m -Xmx512m"
CMD ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]
