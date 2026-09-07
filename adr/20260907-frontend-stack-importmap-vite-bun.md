# ADR: Explicit Importmap/Propshaft and Vite Rails stacks

- Status: accepted
- Date: 2026-09-07

`config/frontend_stacks.yml` is authoritative. Rails application layouts use Importmap, Propshaft,
ERB, Turbo, and Stimulus. Inertia layouts and Vite-owned content use Vite Rails. A surface must not
load the other stack. Bun is only the package manager and script runner; Vite, Vitest, Playwright,
and TypeScript remain the tools.
