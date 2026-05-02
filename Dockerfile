ARG PG_MAJOR=18
ARG PGVECTORSCALE_VERSION=0.9.0
ARG PG_TEXTSEARCH_VERSION=v1.1.0
ARG PGRX_VERSION=0.16.1

# --- Builder Stage ---
FROM rust:1.95-trixie AS builder
ARG PG_MAJOR
ARG PGVECTORSCALE_VERSION
ARG PG_TEXTSEARCH_VERSION
ARG PGRX_VERSION

USER root
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies and Postgres Dev headers
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates gnupg lsb-release curl build-essential git clang pkg-config libssl-dev \
    && echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg \
    && apt-get update && apt-get install -y --no-install-recommends \
    postgresql-server-dev-${PG_MAJOR} \
    && rm -rf /var/lib/apt/lists/*

# Install pgrx and toolchain
RUN cargo install cargo-pgrx --version ${PGRX_VERSION} --locked \
    && cargo pgrx init --pg${PG_MAJOR} /usr/bin/pg_config

# Build pg_textsearch (Standard C extension)
WORKDIR /build/pg_textsearch
RUN git clone --branch ${PG_TEXTSEARCH_VERSION} --depth 1 https://github.com/timescale/pg_textsearch.git . \
    && make && make install

# Build pgvectorscale (Rust extension)
WORKDIR /build/pgvectorscale/pgvectorscale
RUN git clone --branch ${PGVECTORSCALE_VERSION} --depth 1 https://github.com/timescale/pgvectorscale.git . \
    # Use 'native' if building ON the target machine,
    # or 'x86-64-v3' for modern Hetzner Intel/AMD nodes.
    && RUSTFLAGS="-C target-cpu=x86-64-v3" cargo pgrx install --release --pg-config /usr/bin/pg_config

# --- Final Stage ---
FROM ghcr.io/cloudnative-pg/postgresql:18.3-standard-trixie
ARG PG_MAJOR

USER root

# Setup TimescaleDB Repo & Install
RUN apt-get update && apt-get install -y --no-install-recommends curl gnupg ca-certificates \
    && curl -s https://packagecloud.io/install/repositories/timescale/timescaledb/script.deb.sh | bash \
    && apt-get update && apt-get install -y --no-install-recommends \
    timescaledb-2-postgresql-${PG_MAJOR} \
    && apt-get purge -y --auto-remove curl gnupg \
    && rm -rf /var/lib/apt/lists/*

# Copy Extension files using precise pathing
# Libraries (.so)
COPY --from=builder /usr/lib/postgresql/${PG_MAJOR}/lib/vectorscale-*.so /usr/lib/postgresql/${PG_MAJOR}/lib/
COPY --from=builder /usr/lib/postgresql/${PG_MAJOR}/lib/pg_textsearch.so /usr/lib/postgresql/${PG_MAJOR}/lib/

# Extension metadata (.control and .sql)
COPY --from=builder /usr/share/postgresql/${PG_MAJOR}/extension/vectorscale* /usr/share/postgresql/${PG_MAJOR}/extension/
COPY --from=builder /usr/share/postgresql/${PG_MAJOR}/extension/pg_textsearch* /usr/share/postgresql/${PG_MAJOR}/extension/

RUN chown 26:26 /usr/lib/postgresql/${PG_MAJOR}/lib/vectorscale-*.so \
    && chown 26:26 /usr/lib/postgresql/${PG_MAJOR}/lib/pg_textsearch.so

USER 26
