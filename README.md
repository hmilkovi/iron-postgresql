# Iron PostgreSQL - Docker image that contains pg extensions
This is more like a personal repo for my usage but contributions are welcome if someone sees
value to add something that they also want to use or make this more generic.


## Base image
For base image `ghcr.io/cloudnative-pg/postgresql:18.1-standard-trixie` is use with already has:
- PGAudit
- Postgres Failover Slots
- pgvector
- All Locales
- LLVM JIT support
  - From PostgreSQL 18 onwards: provided by the separate `postgresql-MM-jit`
    package

I use only the latest major version of PostgreSQL, currently it's 18.


## Added
Extensions:
- TimescaleDB
- pgvectorscale
