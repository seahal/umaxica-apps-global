# Frontend Architecture Decision: Rails + Importmap + Bun (Toolchain)

## Overview

This document records the architectural decision to use **Rails Importmap** for the runtime
environment and **Bun** solely as a development toolchain (Linter/Formatter).

## Decision

- **Runtime**: Rails Importmap (Hotwire/Turbo/Stimulus). No Node.js runtime in production.
- **Development Toolchain**: Bun + Biome (High-speed Linting/Formatting).

## Rationale

### 1. Operational Simplicity (No Node.js in Production)

- **Benefit**: Removes the need to maintain a Node.js runtime in the production environment.
- **Impact**:
  - Reduced Docker image size.
  - Reduced security attack surface.
  - Lower memory consumption (Pure Ruby/Puma).
  - Aligns with Rails 8 "No-Build" philosophy for default assets.

### 2. Superior Developer Experience (DX)

- **Benefit**: Bun + Biome provides near-instantaneous Linting and Formatting.
- **Impact**:
  - Comparable speed to RuboCop/standard Rails tools.
  - Faster CI/CD pipelines compared to npm/yarn/pnpm.
  - Avoids `node_modules` bloat in simple setups.

### 3. Alignment with "The Rails Way"

- **Benefit**: Hotwire is designed to work without complex build steps.
- **Impact**:
  - Eliminates "Webpack/Esbuild Config Hell".
  - Keeps the focus on Rails development.

## Considerations & Mitigation

### 1. CI/CD & Dockerfile Strategy

- **Challenge**: Bun is needed for linting in CI but not in production.
- **Strategy**: Use **Multi-stage Docker builds**.
  - `build` stage: Install Bun, run Biome/Tests.
  - `release` stage: Copy only necessary assets. Do NOT include Bun runtime.

### 2. JavaScript Library Management

- **Challenge**: Importmap requires ES Module compatible libraries.
- **Strategy**:
  - Use `bin/importmap pin` to fetch from CDNs (jspm, unpkg, etc.).
  - For strict security requirements, use `bin/importmap pin --download` to vendor libraries.

### 3. Future Scalability (Complexity)

- **Challenge**: If complex SPA features (React/Vue with heavy state) are needed later.
- **Strategy**: Adopt a hybrid approach.
  - Stick to Hotwire for 90% of the app.
  - Introduce Vite/Bun build step _only_ for specific complex islands if absolutely necessary.

## Conclusion

This architecture optimizes for "Simple Production, Fast Development," which is the ideal state for
a modern Rails application.
