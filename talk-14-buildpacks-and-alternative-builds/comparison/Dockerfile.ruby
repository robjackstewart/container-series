# syntax=docker/dockerfile:1
FROM ruby:3.3-slim

WORKDIR /app

# --- Corporate CA trust (e.g. Netskope TLS interception) ---------------------
# Supply a corporate CA cert as a BuildKit secret — the cert is not stored in any image layer:
#   docker build --secret id=netskope_cert,src=certs/netskope.crt -t myapp .
# Omit --secret when not behind a proxy; the cert guard in each network RUN is a no-op.
# -----------------------------------------------------------------------------

COPY Gemfile Gemfile.lock ./
RUN --mount=type=secret,id=netskope_cert <<'EOF'
set -e
if [ -s /run/secrets/netskope_cert ]; then
  cp /etc/ssl/certs/ca-certificates.crt /tmp/ca-bundle.orig
  cp /run/secrets/netskope_cert /usr/local/share/ca-certificates/netskope.crt 2>/dev/null || true
  update-ca-certificates 2>/dev/null || cat /run/secrets/netskope_cert >> /etc/ssl/certs/ca-certificates.crt
fi
apt-get update && apt-get install -y build-essential && rm -rf /var/lib/apt/lists/*
rm Gemfile.lock
bundle install
if [ -s /run/secrets/netskope_cert ]; then
  rm -f /usr/local/share/ca-certificates/netskope.crt
  mv /tmp/ca-bundle.orig /etc/ssl/certs/ca-certificates.crt
fi
EOF

COPY . .

EXPOSE 4567
ENV RACK_ENV=production PORT=4567

RUN adduser --disabled-password --gecos '' appuser && chown -R appuser /app
USER appuser

CMD ["bundle", "exec", "ruby", "app.rb"]
