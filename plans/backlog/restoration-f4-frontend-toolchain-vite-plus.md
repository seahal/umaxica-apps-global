# Restoration F4: Frontend Toolchain — Rails Importmap + Vite+ (`vp`)

Extracted from `plans/archive/global-repo-restoration-plan.md` (2026-05-07).

## Source

- `adr/frontend-architecture-toolchain.md` (the file itself still says "Bun" and may also say
  "Biome"; both are out of date — see Adaptation notes).

## Goal

Confirm the documented frontend toolchain matches reality:

- **Rails Importmap** for shipping ES modules to the browser.
- **Vite+** (`vp`) is the unified toolchain wrapper. `vp check` runs both lint and format in one
  pass; `vp check --fix` auto-fixes. Vite+ wraps Oxlint / Oxfmt internally — do not invoke them,
  Biome, ESLint, or Prettier directly.
- **pnpm** is the underlying package manager (lockfile is `pnpm-lock.yaml`; there is no
  `bun.lockb`). Package operations go via `vp add` / `vp install`.
- **Stimulus / Hotwire / Turbo** as the JS layer.
- `package.json` should expose `check` (= `vp check`) and `fix` (= `vp check --fix`) scripts so
  `pnpm run check` / `pnpm run fix` work for editors and CI.

## Key surface

`package.json` (scripts), `pnpm-lock.yaml`, `Dockerfile` multi-stage build, `bin/dev`, CI config,
any docs that mention "Bun" or "Biome".

## Verification

Fresh clone → `vp install` → `vp dev` boots. `vp check` exits 0 on a clean tree. CI uses
`voidzero-dev/setup-vp` (or pnpm directly) and runs `vp check` + `vp test`. No `bun`, `bun.lockb`,
`biome`, `eslint`, or `prettier` binary or config referenced anywhere.

## Adaptation notes

The source ADR text says "Importmap + Bun" and earlier drafts of the master plan said "Biome"; both
are wrong. Real stack is **Importmap + Vite+ (vp) + pnpm**. Either rewrite the ADR (separate task)
or treat this work item as the source of truth. Do **not** introduce Bun, Biome, ESLint, or
Prettier.
