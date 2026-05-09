# Restoration C1: Solid Cache + Solid Queue (Single-App Version)

Extracted from `plans/archive/global-repo-restoration-plan.md` (2026-05-07).

## Source

Background only — `adr/four-app-solid-cache-and-solid-queue.md` is now obsolete (per its own
banner). Re-introduce as a single-app concern.

## Goal

Solid Cache as `Rails.cache` backend; Solid Queue as `ActiveJob` adapter; Puma plugin hook for Solid
Queue.

## Key surface

`config/cache.yml`, `config/queue.yml`, `config/database.yml` (cache + queue DBs), `config/puma.rb`,
environment files.

## Verification

Cache write / read works in test and dev. A trivial job enqueues, executes, and records. `bin/dev`
boots the queue without external services.

## Adaptation notes

**Do not** create per-app cache / queue databases — there is one app. One `cache` DB, one `queue`
DB.
