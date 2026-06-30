FROM ruby:3.3-slim

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

RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 4567
ENV RACK_ENV=production PORT=4567

RUN adduser --disabled-password --gecos '' appuser && chown -R appuser /app
USER appuser

CMD ["bundle", "exec", "ruby", "app.rb"]
