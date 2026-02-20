FROM rust:1.91-bookworm AS pgvectorscale-builder

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates gnupg lsb-release curl && rm -rf /var/lib/apt/lists/*

RUN echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg

# Install build tools, PostgreSQL dev headers, and dependencies for Rust compilation
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git postgresql-server-dev-18 \
    postgresql-18 clang pkg-config libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Install cargo-pgrx: Rust framework for PostgreSQL extension development
RUN cargo install --locked cargo-pgrx --version 0.16.1
# Initialize pgrx with the target PostgreSQL version
RUN cargo pgrx init --pg18 /usr/bin/pg_config

WORKDIR /tmp
RUN git clone --branch 0.9.0 --depth 1 https://github.com/timescale/pgvectorscale.git

WORKDIR /tmp/pgvectorscale/pgvectorscale
# Enable SIMD optimizations (AVX2, FMA) for vectorized operations on x86-64 v3+
ENV RUSTFLAGS="-C target-cpu=x86-64-v3 -C target-feature=+avx2,+fma"
RUN cargo pgrx install --pg-config /usr/bin/pg_config

# -----

FROM ghcr.io/cloudnative-pg/postgresql:18.2-standard-trixie

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

# Copy pgvectorscale extension artifacts (Rust extension)
# Includes compiled .so library and SQL migration files
COPY --from=pgvectorscale-builder \
    /usr/lib/postgresql/18/lib/vectorscale-*.so \
    /usr/lib/postgresql/18/lib/
COPY --from=pgvectorscale-builder \
    /usr/share/postgresql/18/extension/vectorscale*.sql \
    /usr/share/postgresql/18/extension/
COPY --from=pgvectorscale-builder \
    /usr/share/postgresql/18/extension/vectorscale.control \
    /usr/share/postgresql/18/extension/

# Return to the postgres user (UID 26 in CNPG images)
USER 26
