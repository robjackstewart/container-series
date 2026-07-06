# syntax=docker/dockerfile:1
FROM gradle:8.5-jdk21 AS build
WORKDIR /home/gradle/src

# --- Corporate CA trust (e.g. Netskope TLS interception) ---------------------
# Supply a corporate CA cert as a BuildKit secret — the cert is not stored in any image layer:
#   docker build --secret id=netskope_cert,src=certs/netskope.crt -t myapp .
# Omit --secret when not behind a proxy; the cert guard in each network RUN is a no-op.
# -----------------------------------------------------------------------------

RUN chown -R gradle:gradle /home/gradle/src
COPY --chown=gradle:gradle build.gradle.kts settings.gradle.kts ./
COPY --chown=gradle:gradle src ./src
RUN --mount=type=secret,id=netskope_cert <<'EOF'
set -e
if [ -s /run/secrets/netskope_cert ]; then
  keytool -importcert -noprompt -alias netskope -file /run/secrets/netskope_cert -cacerts -storepass changeit
fi
su -s /bin/sh gradle -c 'gradle --no-daemon shadowJar'
if [ -s /run/secrets/netskope_cert ]; then
  keytool -delete -alias netskope -cacerts -storepass changeit
fi
EOF

FROM eclipse-temurin:21-jre-alpine
RUN addgroup -S app && adduser -S app -G app
WORKDIR /app
COPY --from=build /home/gradle/src/build/libs/app.jar /app/app.jar
ENV PORT=8080
EXPOSE 8080
USER app
CMD ["java", "-jar", "/app/app.jar"]
