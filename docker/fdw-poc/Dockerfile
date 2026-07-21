# syntax=docker/dockerfile:1
#
# Disposable PostgreSQL + parquet_s3_fdw proof-of-concept image.
#
# NOT for production or permanent use. This image is isolated from
# docker/psql-pub/Dockerfile (separate build, no shared layers) so it cannot affect the
# permanent database image. It is deleted after the PoC per the cleanup manifest in
# docs/experiments/postgresql-s3-fdw-poc.md.
#
# Pinned to postgres:17.7-bookworm to match docker/psql-pub/Dockerfile exactly --
# parquet_s3_fdw v1.1.1 documents support for PostgreSQL 13-17, so there is no reason to run
# this PoC on a different major version than the project's actual `primary` service.

FROM docker.io/library/postgres:17.7-bookworm AS build

SHELL ["/bin/bash", "-eu", "-o", "pipefail", "-c"]

# Pin every native dependency version. Verify these against the upstream repositories
# before rebuilding -- they were the latest known-good values at authoring time, not a
# guarantee of current compatibility.
ARG PARQUET_S3_FDW_REF=v1.1.1
ARG ARROW_REF=apache-arrow-16.1.0
ARG AWS_SDK_CPP_REF=1.11.335
ARG CMAKE_VERSION=3.29.3

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    git \
    build-essential \
    pkg-config \
    libssl-dev \
    libcurl4-openssl-dev \
    uuid-dev \
    zlib1g-dev \
    ninja-build \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# postgresql-server-dev-17 (headers + pg_config) comes from the PGDG apt repository,
# matching the approach in docker/psql-pub/Dockerfile.
RUN curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    | gpg --dearmor -o /usr/share/keyrings/postgresql-pgdg.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/postgresql-pgdg.gpg] https://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" \
    > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends postgresql-server-dev-17 \
    && rm -rf /var/lib/apt/lists/*

# CMake: install the pinned version directly (Debian bookworm's apt CMake is older than
# parquet_s3_fdw's documented minimum).
RUN ARCH="$(uname -m)" \
    && curl -fsSL -o /tmp/cmake-install.sh \
       "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-${ARCH}.sh" \
    && sh /tmp/cmake-install.sh --skip-license --prefix=/usr/local \
    && rm /tmp/cmake-install.sh

WORKDIR /usr/local/src

# Apache Arrow / libparquet, built from source per upstream guidance against precompiled
# binaries (linker/GCC mismatches across distributions).
RUN git clone --branch "${ARROW_REF}" --depth 1 https://github.com/apache/arrow.git \
    && cmake -S arrow/cpp -B arrow/cpp/build -G Ninja \
       -DCMAKE_BUILD_TYPE=Release \
       -DARROW_PARQUET=ON \
       -DARROW_WITH_SNAPPY=ON \
       -DARROW_WITH_ZSTD=ON \
       -DARROW_BUILD_SHARED=ON \
       -DARROW_BUILD_STATIC=OFF \
       -DARROW_BUILD_TESTS=OFF \
       -DARROW_BUILD_EXAMPLES=OFF \
    && cmake --build arrow/cpp/build \
    && cmake --install arrow/cpp/build \
    && ldconfig \
    && rm -rf arrow

# AWS SDK for C++ (core + s3 modules only), built from source, pinned version.
RUN git clone --branch "${AWS_SDK_CPP_REF}" --depth 1 --recurse-submodules \
       https://github.com/aws/aws-sdk-cpp.git \
    && cmake -S aws-sdk-cpp -B aws-sdk-cpp/build -G Ninja \
       -DCMAKE_BUILD_TYPE=Release \
       -DBUILD_ONLY="s3" \
       -DENABLE_TESTING=OFF \
       -DAUTORUN_UNIT_TESTS=OFF \
    && cmake --build aws-sdk-cpp/build \
    && cmake --install aws-sdk-cpp/build \
    && ldconfig \
    && rm -rf aws-sdk-cpp

# parquet_s3_fdw itself, against PG17 headers.
RUN git clone --branch "${PARQUET_S3_FDW_REF}" --depth 1 \
       https://github.com/pgspider/parquet_s3_fdw.git \
    && cd parquet_s3_fdw \
    && make USE_PGXS=1 PG_CONFIG=/usr/lib/postgresql/17/bin/pg_config \
    && make USE_PGXS=1 PG_CONFIG=/usr/lib/postgresql/17/bin/pg_config install

FROM docker.io/library/postgres:17.7-bookworm

# Runtime-only image: copy the built extension and its shared-library dependencies,
# skip the full build toolchain to keep the final image reasonably sized.
COPY --from=build /usr/lib/postgresql/17/lib/parquet_s3_fdw.so /usr/lib/postgresql/17/lib/
COPY --from=build /usr/share/postgresql/17/extension/parquet_s3_fdw* /usr/share/postgresql/17/extension/
COPY --from=build /usr/local/lib/ /usr/local/lib/
RUN ldconfig
