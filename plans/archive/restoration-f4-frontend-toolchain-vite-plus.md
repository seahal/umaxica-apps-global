# Restoration F4: Frontend Toolchain — Vite Rails + Vite+ (`vp`)

Extracted from `plans/archive/global-repo-restoration-plan.md` (2026-05-07).

## Source

- `adr/frontend-architecture-toolchain.md` (the file itself still says "Bun" and may also say
  "Biome"; both are out of date — see Adaptation notes).

## Goal

Confirm the documented frontend toolchain matches reality:

- **Vite Rails** for shipping browser JavaScript entrypoints.
- **Vite+** (`vp`) is the unified toolchain wrapper. `vp check` runs both lint and format in one
  pass; `vp check --fix` auto-fixes. Vite+ wraps Oxlint / Oxfmt internally — do not invoke them,
  Biome, ESLint, or Prettier directly.
- **pnpm** is the underlying package manager (lockfile is `pnpm-lock.yaml`; there is no
  `bun.lockb`). Package operations go via `vp add` / `vp install`.
- **Stimulus / Hotwire / Turbo** as the JS layer.
- `package.json` should expose `check` (= `vp check`) and `fix` (= `vp check --fix`) scripts so
  `pnpm run check` / `pnpm run fix` work for editors and CI.
- Rails Tailwind CLI and Propshaft remain the default path for CSS and static assets.

## Key surface

`package.json` (scripts and runtime JS dependencies), `pnpm-lock.yaml`, `Dockerfile` multi-stage
build, `bin/dev`, Vite entrypoints, CI config, and docs that mention Importmap, Bun, or Biome.

## Verification

Fresh clone → `vp install` → `vp dev` boots. `vp check` exits 0 on a clean tree. CI uses
`voidzero-dev/setup-vp` (or pnpm directly) and runs `vp check` + `vp test`. Rails validation runs
`bin/rails vite:build` and `bin/rails assets:precompile`. No app-owned `config/importmap.rb`,
`bin/importmap`, `javascript_importmap_tags`, `bun`, `bun.lockb`, `biome`, `eslint`, or `prettier`
binary or config referenced anywhere.

## Adaptation notes

The source ADR was rewritten for Vite Rails. `importmap-rails` can still appear in `Gemfile.lock` as
a transitive dependency of `mission_control-jobs`; that is not an application JavaScript entrypoint
dependency and should not reintroduce importmap pins or layout tags. Do **not** introduce Bun,
Biome, ESLint, or Prettier.
