# syntax=docker/dockerfile:1
# check=error=true
# ============================================================================
# Shared build arguments
# ============================================================================
ARG RUBY_VERSION=4.0.5
ARG DOCKER_UID=1000
ARG DOCKER_GID=1000
ARG DOCKER_USER=global
ARG DOCKER_GROUP=umaxica
ARG GITHUB_ACTIONS=""
ARG NODE_MAJOR=26

# ============================================================================
# Node.js toolchain (binaries copied into the development image)
# ============================================================================
FROM node:${NODE_MAJOR}-trixie-slim AS node-toolchain

# ============================================================================
# Production base — runtime-only dependencies
# ============================================================================
FROM ruby:${RUBY_VERSION}-slim-trixie AS production-base
SHELL ["/bin/bash", "-eu", "-o", "pipefail", "-c"]
ARG DOCKER_UID
ARG DOCKER_GID
ARG DOCKER_USER
ARG DOCKER_GROUP
ENV HOME=/home/${DOCKER_USER}
ENV APP_HOME=${HOME}/main
ENV LANG=C.UTF-8 \
    RAILS_ENV=production \
    RACK_ENV=production \
    BUNDLE_WITHOUT=development:test \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_APP_CONFIG=/usr/local/bundle/.bundle \
    BUNDLE_FROZEN=1 \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3

WORKDIR ${APP_HOME}

RUN if ! getent group "${DOCKER_GROUP}" >/dev/null; then \
    groupadd --gid "${DOCKER_GID}" "${DOCKER_GROUP}"; \
    fi \
    && if ! id -u "${DOCKER_USER}" >/dev/null 2>&1; then \
    useradd --uid "${DOCKER_UID}" --gid "${DOCKER_GROUP}" --home "${HOME}" --shell /usr/sbin/nologin "${DOCKER_USER}"; \
    fi \
    && mkdir -p "${APP_HOME}" "${HOME}" \
    && chown -R "${DOCKER_UID}:${DOCKER_GID}" "${HOME}"

# apt lists / archives live in BuildKit cache mounts (not in the image layer),
# so rebuilds reuse downloads while the final image stays clean.
# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \
    && apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
    ca-certificates \
    libjemalloc2 \
    libpq5 \
    libyaml-0-2 \
    tzdata \
    && rm -f /usr/local/bin/gosu /usr/local/bin/gosu-*

# ============================================================================
# Production build — gems + asset/bootsnap precompile
# ============================================================================
FROM production-base AS production-build
ARG DOCKER_UID
ARG DOCKER_GID

# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    libpq-dev \
    libyaml-dev \
    pkg-config \
    unzip

COPY Gemfile Gemfile.lock ./
RUN --mount=type=cache,target=/tmp/bundle-cache,uid=${DOCKER_UID},gid=${DOCKER_GID} \
    bundle config set --local cache_path /tmp/bundle-cache \
    && bundle install --jobs "${BUNDLE_JOBS}" --retry "${BUNDLE_RETRY}" \
    && bundle exec bootsnap precompile --gemfile \
    && bundle clean --force \
    && rm -rf /usr/local/bundle/cache

COPY . .

RUN install -d tmp/pids log \
    && rm -rf tmp/cache \
    && find log -type f -exec truncate -s 0 {} + \
    && rm -f tmp/pids/server.pid \
    && bundle exec bootsnap precompile app/ lib/

# ============================================================================
# Production runtime
# ============================================================================
FROM production-base AS production
ARG DOCKER_UID
ARG DOCKER_GID
ARG DOCKER_USER
ENV PORT=8080 \
    RUBY_YJIT_ENABLE=1 \
    RAILS_LOG_TO_STDOUT=1 \
    RAILS_SERVE_STATIC_FILES=true \
    LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2 \
    PATH=/usr/local/bundle/bin:${PATH}

COPY --from=production-build --chown=${DOCKER_UID}:${DOCKER_GID} /usr/local/bundle /usr/local/bundle
COPY --from=production-build --chown=${DOCKER_UID}:${DOCKER_GID} ${APP_HOME} ${APP_HOME}

# Single hardening layer: lock out root + drop privilege-escalation paths,
# create owner-only writable runtime dirs, then make app + bundle read/exec only.
# Order is preserved: writable dirs are created before the chmod 500 sweep,
# which deliberately excludes tmp/log/storage.
RUN usermod -s /usr/sbin/nologin root \
    && usermod -L root \
    && rm -f /usr/bin/sudo /usr/bin/su /usr/sbin/sudo /usr/sbin/su \
    && rm -f /usr/bin/chsh /usr/bin/chfn /usr/bin/newgrp /usr/bin/passwd /usr/bin/gpasswd \
    && find / -xdev -perm /4000 -exec chmod u-s {} + 2>/dev/null || true \
    && find / -xdev -perm /2000 -exec chmod g-s {} + 2>/dev/null || true \
    && install -d -m 700 -o "${DOCKER_UID}" -g "${DOCKER_GID}" \
    tmp tmp/pids tmp/cache tmp/sockets \
    log \
    storage \
    && find "${APP_HOME}" -mindepth 1 \
    ! -type l \
    ! -path "${APP_HOME}/tmp/*" \
    ! -path "${APP_HOME}/log/*" \
    ! -path "${APP_HOME}/storage/*" \
    -exec chmod 500 {} + \
    && find /usr/local/bundle ! -type l -exec chmod 500 {} +

USER ${DOCKER_USER}

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD ruby -rsocket -e "TCPSocket.new('127.0.0.1', Integer(ENV.fetch('PORT', '8080'))).close"

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb", "--port", "8080"]

# ============================================================================
# Development base — system packages for the docker compose workflow
# ============================================================================
FROM ruby:${RUBY_VERSION}-trixie AS development-base
SHELL ["/bin/bash", "-eu", "-o", "pipefail", "-c"]
ENV TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2

# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \
    && apt-get update -qq \
    && apt-get install --no-install-recommends -y \
    build-essential \
    ca-certificates \
    curl \
    git \
    gnupg \
    graphviz \
    libjemalloc2 \
    libpq-dev \
    libvips \
    libxml2-dev \
    libyaml-dev \
    postgresql-client \
    tzdata \
    unzip \
    zlib1g-dev \
    && rm -rf /tmp/* /var/tmp/*

# ============================================================================
# Development image (used by docker compose)
# ============================================================================
FROM development-base AS development
SHELL ["/bin/bash", "-eu", "-o", "pipefail", "-c"]
ARG DOCKER_UID
ARG DOCKER_GID
ARG DOCKER_USER
ARG DOCKER_GROUP
ARG GITHUB_ACTIONS
ENV HOME=/home/${DOCKER_USER}
WORKDIR ${HOME}/workspace

COPY --from=node-toolchain /usr/local/bin/node /usr/local/bin/node
COPY --from=node-toolchain /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -sf ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
    && ln -sf ../lib/node_modules/corepack/dist/corepack.js /usr/local/bin/corepack

# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \
    && curl -1sLf "https://dl.cloudsmith.io/public/evilmartians/lefthook/setup.deb.sh" | bash \
    && apt-get update -qq \
    && apt-get install --no-install-recommends -y \
    bat \
    bubblewrap \
    entr \
    fd-find \
    fontconfig \
    fzf \
    git-secrets \
    gitleaks \
    htop \
    iproute2 \
    jq \
    lefthook \
    lsb-release \
    ncdu \
    netcat-openbsd \
    openssl \
    ripgrep \
    silversearcher-ag \
    socat \
    sudo \
    tig \
    tree \
    watch \
    wget \
    yq \
    zip \
    && rm -rf /tmp/* /var/tmp/* "/home/${DOCKER_USER}/"

RUN if [ -z "${GITHUB_ACTIONS}" ]; then \
    groupadd -g "${DOCKER_GID}" "${DOCKER_GROUP}"; \
    useradd -l -u "${DOCKER_UID}" -g "${DOCKER_GROUP}" -m -s /bin/bash "${DOCKER_USER}"; \
    echo "${DOCKER_USER}:${DOCKER_USER_PASSWORD:-devpassword}" | chpasswd; \
    echo "${DOCKER_USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers; \
    else \
    mkdir -p "${HOME}"; \
    fi

# Install pnpm for development use only (available by default on PATH).
RUN npm install -g pnpm@11.0.8 \
    && rm -rf "${HOME}/.cache" "${HOME}/.local"

# Install Vite+ (unified frontend toolchain: Vite, Vitest, Oxlint, Oxfmt, tsdown)
RUN curl -fsSL https://vite.plus | bash
ENV PATH="${HOME}/.vite-plus/bin:${PATH}"

# Final ownership fix for the home directory and workspace
RUN mkdir -p "${HOME}/workspace" \
    && chown -R "${DOCKER_UID}:${DOCKER_GID}" "${HOME}"

USER ${DOCKER_USER}
