# Engine Ownership Classification Plan

## Status

Active draft (2026-04-18)

## Summary

Classify every current root-owned file into one destination:

- move to engine
- move to wrapper app
- move to `lib/`
- delete during root app retirement

## Classification Rules

### Move to engine

Use this for:

- models
- DB base records
- persistence-aware services
- engine-specific concerns
- engine-specific helpers
- engine views
- engine assets
- engine locale files

### Move to wrapper app

Use this for:

- `config/application.rb` responsibilities
- runtime initializers
- `config/importmap.rb`
- runtime session and middleware boot
- runtime asset boot

### Move to `lib/`

Use this only for code that is:

- engine-neutral
- persistence-neutral
- route-neutral
- runtime-neutral or reusable boot support

### Delete

Use this for:

- root-only compatibility layers
- root boot files made obsolete by wrapper apps
- old path layout compatibility files

## Mandatory Inventory Scope

- root `config/application.rb`
- root `config/initializers/*`
- root `config/importmap.rb`
- root `app/views/layouts/*`
- root `app/models/*`
- root `app/services/*`
- root `app/controllers/concerns/*`
- root `app/helpers/*`

## Acceptance

- every root-owned runtime or domain file has exactly one destination
- no unclassified root file remains in the migration plan
