# Engine Ownership Classification Results

## Status

Completed (2026-04-18)

## Summary

Classification of root-owned files according to the Engine Ownership Classification Plan.

## Classification Results

### Move to Wrapper App

Runtime configuration and initialization files that belong in the wrapper application:

- `config/application.rb`
- `config/importmap.rb`
- `config/initializers/*` (all initializer files)
- `app/views/layouts/*` (all layout templates)

### Move to Engine

Domain logic, persistence-aware code, and engine-specific components:

- `app/models/*` (all model files)
- `app/services/*` (most service files, except pure utilities)
- `app/controllers/concerns/*` (all controller concerns)
- `app/helpers/application_helper.rb`

### Move to `lib/`

Engine-neutral, persistence-neutral utility code:

- `app/services/cache_aside.rb` (generic caching utility)

### Delete During Root App Retirement

Files that are root-only compatibility layers or obsolete:

- None identified

## Rationale

Following the classification rules in the plan:

1. Models are moved to engine as they represent domain logic and persistence
2. Services are mostly moved to engine as they are typically persistence-aware or domain-specific
3. Controller concerns are moved to engine as they are engine-specific functionality
4. Initializers and application.rb are moved to wrapper app as they handle runtime configuration
5. Layouts are moved to wrapper app as they are application-level view templates
6. Pure utility services like CacheAside are moved to lib/ as they are engine-neutral
