FROM rocker/r-ver:4.3.0 AS base

# The Rocker project provides curated R images, so we can start from a clean
# R runtime instead of compiling R by hand inside a generic Linux image.
ENV DEBIAN_FRONTEND=noninteractive
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

RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

RUN R -q -e "install.packages(c('plumber', 'jsonlite'), repos='https://cloud.r-project.org')"

FROM base AS model-builder
COPY src/train_model.R /app/train_model.R
RUN Rscript /app/train_model.R

FROM base AS runtime
RUN groupadd --system plumber \
    && useradd --system --gid plumber --home-dir /app --no-create-home plumber
COPY --from=model-builder --chown=plumber:plumber /app/model.rds /app/model.rds
COPY --chown=plumber:plumber src/api.R /app/api.R

USER plumber
EXPOSE 8000

CMD ["R", "-q", "-e", "api <- plumber::plumb('/app/api.R'); api$run(host = '0.0.0.0', port = 8000)"]
