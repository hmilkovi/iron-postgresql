FROM ghcr.io/cloudnative-pg/postgresql:18.3-standard-trixie

USER root

# 1. Install dependencies for adding repositories
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    gnupg \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 2. Add TimescaleDB GPG key and repository
RUN curl -s https://packagecloud.io/install/repositories/timescale/timescaledb/script.deb.sh | bash

# 3. Install TimescaleDB for PostgreSQL 18
# Note: Ensure the package name matches the versioning in the repo (usually timescaledb-2-postgresql-18)
RUN apt-get update && apt-get install -y --no-install-recommends \
    timescaledb-2-postgresql-18 \
    && rm -rf /var/lib/apt/lists/*

# Return to the postgres user (UID 26 in CNPG images)
USER 26
