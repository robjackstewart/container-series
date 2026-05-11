FROM rocker/r-ver:4.3.0 AS base

# The Rocker project provides curated R images, so we can start from a clean
# R runtime instead of compiling R by hand inside a generic Linux image.
ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /app

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
COPY --from=model-builder /app/model.rds /app/model.rds
COPY src/api.R /app/api.R

EXPOSE 8000

CMD ["R", "-q", "-e", "api <- plumber::plumb('/app/api.R'); api$run(host = '0.0.0.0', port = 8000)"]
