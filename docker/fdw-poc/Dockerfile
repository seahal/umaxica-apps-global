# syntax=docker/dockerfile:1
#
# Disposable PostgreSQL + Supabase Wrappers (S3 FDW) proof-of-concept image.
#
# NOT for production or permanent use. This image is isolated from
# docker/psql-pub/Dockerfile (different PostgreSQL major version, different extension
# set) so it cannot affect the permanent database image. It is deleted after the PoC
# per the cleanup manifest in docs/experiments/postgres-s3-fdw-poc.md (Gate 2c).
#
# Wrappers' PostgreSQL 17 support was unconfirmed at authoring time, so this pins
# PostgreSQL 16, distinct from psql-pub's 17.7.

FROM docker.io/library/postgres:16-bookworm

SHELL ["/bin/bash", "-eu", "-o", "pipefail", "-c"]

# Pin explicit versions so the build is reproducible. Verify these against the
# upstream repositories before building — they were the latest known-good values at
# authoring time, not a guarantee of current compatibility.
ARG WRAPPERS_REF=v0.4.5
ARG CARGO_PGRX_VERSION=0.12.9

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    git \
    build-essential \
    pkg-config \
    libssl-dev \
    clang \
    && rm -rf /var/lib/apt/lists/*

# postgresql-server-dev-16 (headers + pg_config) comes from the PGDG apt repository,
# matching the approach in docker/psql-pub/Dockerfile.
RUN curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    | gpg --dearmor -o /usr/share/keyrings/postgresql-pgdg.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/postgresql-pgdg.gpg] https://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" \
    > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends postgresql-server-dev-16 \
    && rm -rf /var/lib/apt/lists/*

# cargo pgrx refuses to run as root, so build as an unprivileged user.
RUN useradd --create-home --shell /bin/bash pgrx-builder
USER pgrx-builder
WORKDIR /home/pgrx-builder
ENV PATH="/home/pgrx-builder/.cargo/bin:${PATH}"

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --default-toolchain stable --profile minimal

RUN cargo install --locked cargo-pgrx --version "${CARGO_PGRX_VERSION}" \
    && cargo pgrx init --pg16 "$(command -v pg_config)"

# Confirm the exact cargo feature name for the S3 wrapper against the pinned
# WRAPPERS_REF's Cargo.toml before relying on this build — feature names have
# changed across Wrappers releases.
RUN git clone --branch "${WRAPPERS_REF}" --depth 1 https://github.com/supabase/wrappers.git \
    && cd wrappers/wrappers \
    && cargo pgrx install --release --pg-config "$(command -v pg_config)" \
       --no-default-features --features s3_fdw

USER root
