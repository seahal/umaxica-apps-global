# syntax=docker/dockerfile:1

# ============================================================================
# Shared build arguments
# ============================================================================
ARG RUBY_VERSION=4.0.3
ARG DOCKER_UID=1000
ARG DOCKER_GID=1000
ARG DOCKER_USER=global
ARG DOCKER_GROUP=umaxica
ARG GITHUB_ACTIONS=""

# ============================================================================
# Production image (multi-stage build)
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

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
    ca-certificates \
    libpq5 \
    libyaml-0-2 \
    tzdata \
    && rm -f /usr/local/bin/gosu /usr/local/bin/gosu-* \
    && rm -rf /var/lib/apt/lists/*


# ============================================================================
# ============================================================================

FROM production-base AS production-build
# Install build tools required for gems
ARG DOCKER_UID
ARG DOCKER_GID
# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    libpq-dev \
    libyaml-dev \
    pkg-config \
    unzip \
    && rm -rf /var/lib/apt/lists/*

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
# ============================================================================
FROM production-base AS production
ARG DOCKER_UID
ARG DOCKER_GID
ARG DOCKER_USER
ENV PORT=8080 \
    RUBY_YJIT_ENABLE=1 \
    RAILS_LOG_TO_STDOUT=1 \
    RAILS_SERVE_STATIC_FILES=true \
    PATH=/usr/local/bundle/bin:${PATH}

COPY --from=production-build --chown=${DOCKER_UID}:${DOCKER_GID} /usr/local/bundle /usr/local/bundle
COPY --from=production-build --chown=${DOCKER_UID}:${DOCKER_GID} ${APP_HOME} ${APP_HOME}

# Harden: lock out root and remove privilege escalation paths
RUN usermod -s /usr/sbin/nologin root \
    && usermod -L root \
    && rm -f /usr/bin/sudo /usr/bin/su /usr/sbin/sudo /usr/sbin/su \
    && rm -f /usr/bin/chsh /usr/bin/chfn /usr/bin/newgrp /usr/bin/passwd /usr/bin/gpasswd \
    && find / -xdev -perm /4000 -exec chmod u-s {} + 2>/dev/null || true \
    && find / -xdev -perm /2000 -exec chmod g-s {} + 2>/dev/null || true

# Writable directories for Rails runtime (owner-only rwx)
RUN install -d -m 700 -o "${DOCKER_UID}" -g "${DOCKER_GID}" \
    tmp tmp/pids tmp/cache tmp/sockets \
    log \
    storage

# Lock down app files: read + execute only (no write), owner-only
RUN find "${APP_HOME}" -mindepth 1 \
    ! -type l \
    ! -path "${APP_HOME}/tmp/*" \
    ! -path "${APP_HOME}/log/*" \
    ! -path "${APP_HOME}/storage/*" \
    -exec chmod 500 {} + \
    && find /usr/local/bundle ! -type l -exec chmod 500 {} +

USER ${DOCKER_USER}

EXPOSE 8080

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb", "--port", "8080"]

# ============================================================================
# Development image (used by docker compose)
# ============================================================================
FROM ruby:${RUBY_VERSION}-trixie AS development-base
SHELL ["/bin/bash", "-eu", "-o", "pipefail", "-c"]
ENV TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    BUNDLE_FORCE_RUBY_PLATFORM=1

# hadolint ignore=DL3008
RUN apt-get update -qq \
    && apt-get install --no-install-recommends -y \
    build-essential \
    ca-certificates \
    curl \
    git \
    gnupg \
    libpq-dev \
    libvips \
    libxml2-dev \
    libyaml-dev \
    postgresql-client \
    tzdata \
    unzip \
    zlib1g-dev \
    graphviz \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /var/tmp/*

# ============================================================================
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

# hadolint ignore=DL3008
RUN curl -1sLf "https://dl.cloudsmith.io/public/evilmartians/lefthook/setup.deb.sh" | bash \
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
    yq \
    lsb-release \
    ncdu \
    nodejs \
    npm \
    openssl \
    ripgrep \
    silversearcher-ag \
    sudo \
    tig \
    tree \
    watch \
    wget \
    zip \
    socat \
    netcat-openbsd \
    bubblewrap \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /var/tmp/* "/home/${DOCKER_USER}/"

RUN if [ -z "${GITHUB_ACTIONS}" ]; then \
    groupadd -g "${DOCKER_GID}" "${DOCKER_GROUP}"; \
    useradd -l -u "${DOCKER_UID}" -g "${DOCKER_GROUP}" -m -s /bin/bash "${DOCKER_USER}"; \
    echo "${DOCKER_USER}:${DOCKER_USER_PASSWORD:-devpassword}" | chpasswd; \
    echo "${DOCKER_USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers; \
    else \
    mkdir -p "${HOME}"; \
    fi

# Install pnpm for development use only (available by default on PATH).
RUN npm install -g pnpm@10.27.0 && \
    rm -rf "${HOME}/.cache" "${HOME}/.local"

# Install Vite+ (unified frontend toolchain: Vite, Vitest, Oxlint, Oxfmt, tsdown)
RUN curl -fsSL https://vite.plus | bash
ENV PATH="${HOME}/.vite-plus/bin:${PATH}"

# Final ownership fix for the home directory and workspace
RUN mkdir -p "${HOME}/workspace" && \
    chown -R "${DOCKER_UID}:${DOCKER_GID}" "${HOME}"

USER ${DOCKER_USER}
