# Refactor: File Name Cleanup

## Status

Refreshed (2026-05-07). Phase 1 is already done. Phases 2a, 2b, 2c, 3, 4 are not started. Counts,
paths, and the Phase 4 database mapping have been re-verified against the current tree.

## Context

Several file names in this codebase have problematic English: grammatically wrong words, unclear
abbreviations, or semantically strange pluralization. This refactor corrects 6 naming issues without
changing functionality.

## Changes (ordered by execution sequence)

### Phase 1: Dead code removal — ✅ DONE (2026-05-07)

**Delete `stagings` orphan view**

- Delete `app/views/core/com/stagings/show.html.erb`
- No controller, no route, no references anywhere. Confirmed dead code.
- Risk: none
- Status: file already removed. This phase needs no further work.

---

### Phase 2: Simple concern renames (no DB impact, independent of each other)

**2a: `accountably` -> `accountable`**

"Accountably" is an adverb. The concern defines a contract interface, so the adjective form
`Accountable` is correct (matching Rails convention: `Authenticatable`, `Withdrawable`, etc.).

Files to change:

| Action        | Path                                                                                                    |
| ------------- | ------------------------------------------------------------------------------------------------------- |
| Rename + edit | `app/models/concerns/accountably.rb` -> `accountable.rb` (`module Accountably` -> `module Accountable`) |
| Edit          | `app/models/concerns/identity.rb` line 9: `include ::Accountably` -> `include ::Accountable`            |
| Rename + edit | `test/models/accountably_test.rb` -> `accountable_test.rb` (class name + module refs)                   |
| Edit          | `.github/copilot-instructions.md` (references to `Accountably` concern)                                 |

Risk: low (5 files)

---

**2b: Delete `cat_tag` concern (dead code)**

The `cat_tag.rb` concern is an empty module with no callers. Verified 2026-05-07: a repo-wide grep
for `CatTag` returns only the concern definition and its test file — no `include ::CatTag` or
`include CatTag` references in `app/models/`. The previous draft of this plan listed nine including
models (`*_document_*`, `*_timeline_*`); those models do not exist in the current tree (docs / news
/ timeline content moved to the regional repo per `adr/split-into-regional-and-global-repos.md`).
The concern is therefore dead code and should be deleted, not renamed.

Files to change:

| Action | Path                                   |
| ------ | -------------------------------------- |
| Delete | `app/models/concerns/cat_tag.rb`       |
| Delete | `test/models/concerns/cat_tag_test.rb` |

Verification:

```bash
grep -rn "CatTag\|cat_tag" app/ test/ lib/ config/
```

Should return zero matches after deletion.

Risk: low (2 files, no callers — pure dead-code removal)

---

**2c: `consume_once_token` -> `single_use_token`**

"Consume once token" is awkward verb-first naming. "Single-use token" is the standard security term
for this pattern.

Files to change:

| Action        | Path                                                                                                                        |
| ------------- | --------------------------------------------------------------------------------------------------------------------------- |
| Rename + edit | `app/models/concerns/consume_once_token.rb` -> `single_use_token.rb` (`module ConsumeOnceToken` -> `module SingleUseToken`) |
| Edit          | `app/models/app_preference.rb` line 56: `include ::ConsumeOnceToken` -> `include ::SingleUseToken`                          |
| Edit          | `app/models/com_preference.rb` line 56: same                                                                                |
| Edit          | `app/models/org_preference.rb` line 56: same                                                                                |

Note: Internal method names (`consume_once_by_digest!`, `rotate!`) describe actions, not the module.
They do NOT need to change.

Risk: low (4 files)

**Important**: Do Phase 2c BEFORE Phase 4, because Phase 4 also modifies the same concern file.

---

### Phase 3: Controller rename

**`healths` -> `health` (singular)**

"Health" is an uncountable noun in English. "Healths" is not a real word.

**Caveat**: Rails `resource :health` auto-maps to `HealthsController` by convention. The current
naming IS technically correct Rails. Renaming to `HealthController` requires adding
`controller: "health"` to every route line so Rails finds the right controller.

**Controller files to rename**

All `healths_controller.rb` -> `health_controller.rb`, class `HealthsController` ->
`HealthController` for current non-probe health snapshot controllers:

- `app/controllers/acme/{app,com,org}/healths_controller.rb` (3)
- `app/controllers/core/{app,com,org}/healths_controller.rb` (3)
- `app/controllers/sign/{app,com,org}/healths_controller.rb` (3)

Do not reintroduce retired `/edge/v0/health` or Sign `/web/v0/health` controllers while doing this
cleanup. Probe controllers under `health/lives`, `health/readies`, and `health/startups` already
follow Rails' plural controller convention.

**Route files to update**

For snapshot controllers in `config/routes/acme.rb`, `config/routes/core.rb`, and
`config/routes/sign.rb`, every occurrence of:

```ruby
resource :health, only: :show
```

becomes:

```ruby
resource :health, only: :show, controller: "health"
```

**Test files to rename**

All `healths_controller_test.rb` -> `health_controller_test.rb`, update class names inside. Mirror
the controller paths above (test paths follow `test/controllers/<boundary>/...`).

**Verify after renaming**

```bash
grep -rn "HealthsController\|healths_controller" app/ test/ config/
```

Should return zero matches. The `core/controller_inheritance_test.rb` reference in the previous
draft no longer applies — that file is gone with the `core/` boundary.

Risk: medium (~30 files, no DB impact)

---

### Phase 4: Database-impacting rename (largest change, do last)

**`colortheme` -> `theme`**

"Colortheme" is a compound word missing the underscore separator. The user decided to shorten it to
just "theme" since the preference context already implies color.

12 DB tables across 3 databases. Re-grep after Phase 2c to confirm the `colortheme` reference count
for the current tree before starting Step 2 (the previous "494 occurrences across 130 files" figure
is from an older snapshot and has drifted).

#### Step 1: DB migrations (3 new migration files)

Create one migration per database using `rename_table`. Check for explicitly named indexes and
foreign keys that also need renaming. Verified table locations as of 2026-05-07:

| Database  | Migration dir                 | Tables to rename                                                                       |
| --------- | ----------------------------- | -------------------------------------------------------------------------------------- |
| principal | `db/principals_migrate/`      | `{app,user}_preference_colortheme{s,_options}` -> `*_theme{s,_options}` (4 tables)     |
| operator  | `db/operators_migrate/`       | `{org,staff}_preference_colortheme{s,_options}` -> `*_theme{s,_options}` (4 tables)    |
| setting   | `db/com_preferences_migrate/` | `{com,customer}_preference_colortheme{s,_options}` -> `*_theme{s,_options}` (4 tables) |

Note: `staff_preference_colortheme*` lives in `operator` (moved per the staff-preference DB
migration archived 2026-05-07). `com` and `customer` preference tables live in `com_preference`.
There is no `commerce` DB and no colortheme tables in `guest`.

#### Step 2: Rename 12 model files

| Old file                                              | New file                              |
| ----------------------------------------------------- | ------------------------------------- |
| `app/models/app_preference_colortheme.rb`             | `app_preference_theme.rb`             |
| `app/models/app_preference_colortheme_option.rb`      | `app_preference_theme_option.rb`      |
| `app/models/com_preference_colortheme.rb`             | `com_preference_theme.rb`             |
| `app/models/com_preference_colortheme_option.rb`      | `com_preference_theme_option.rb`      |
| `app/models/org_preference_colortheme.rb`             | `org_preference_theme.rb`             |
| `app/models/org_preference_colortheme_option.rb`      | `org_preference_theme_option.rb`      |
| `app/models/staff_preference_colortheme.rb`           | `staff_preference_theme.rb`           |
| `app/models/staff_preference_colortheme_option.rb`    | `staff_preference_theme_option.rb`    |
| `app/models/user_preference_colortheme.rb`            | `user_preference_theme.rb`            |
| `app/models/user_preference_colortheme_option.rb`     | `user_preference_theme_option.rb`     |
| `app/models/customer_preference_colortheme.rb`        | `customer_preference_theme.rb`        |
| `app/models/customer_preference_colortheme_option.rb` | `customer_preference_theme_option.rb` |

Update all class names, `belongs_to`/`has_many` association names, `class_name:` and `inverse_of:`
references inside each file.

#### Step 3: Update parent model associations (6 files)

- `app/models/app_preference.rb`: `has_one :app_preference_colortheme` -> `:app_preference_theme`
- `app/models/com_preference.rb`: same pattern
- `app/models/org_preference.rb`: same pattern
- `app/models/user_preference.rb`: same pattern
- `app/models/staff_preference.rb`: same pattern
- `app/models/customer_preference.rb`: same pattern

#### Step 4: Update service registry

- `app/services/preference/class_registry.rb`: all `:colortheme` keys -> `:theme`, all
  `*Colortheme*` class references -> `*Theme*`

#### Step 5: Update concerns and controllers

- `app/models/concerns/single_use_token.rb` (renamed in Phase 2c): `"colortheme"` string on line 79
  -> `"theme"`
- `app/controllers/concerns/preference/core.rb`: methods `set_colortheme_preferences_edit` ->
  `set_theme_preferences_edit`, `set_colortheme_preferences_update` ->
  `set_theme_preferences_update`, `preference_colortheme_params` -> `preference_theme_params`
- `app/controllers/concerns/preference/base.rb`: all colortheme references
- `app/controllers/concerns/preference/edge.rb`: all colortheme references
- `app/controllers/concerns/preference/global.rb`: all colortheme references
- `app/controllers/concerns/preference/regional.rb`: all colortheme references
- `app/controllers/concerns/preference/web_theme_endpoint.rb`: all colortheme references
- `app/controllers/concerns/preference/adoption.rb`: all colortheme references

#### Step 6: Update helpers

- `app/helpers/sign/common_helper.rb`: `get_colortheme` -> `get_theme` (the
  `app/helpers/docs/common_helper.rb` referenced in earlier drafts no longer exists — the `docs/`
  boundary was retired with the regional repo split.)

#### Step 7: Update views (6 edit templates + 2 partials)

- `app/views/sign/{app,com,org}/preference/themes/edit.html.erb`: `@preference_colortheme` ->
  `@preference_theme`, param scope names
- `app/views/acme/{app,com,org}/preference/themes/edit.html.erb`: same (path is `acme/`, not `acme/`
  — earlier drafts referenced the old `acme/` path.)
- `app/views/sign/shared/preference/_theme_form.html.erb` and
  `app/views/acme/shared/preference/_theme_form.html.erb`: any `colortheme` references in the shared
  partials.

#### Step 8: Update rake task

- `lib/tasks/preference_migration.rake`: `"colortheme"` -> `"theme"`

#### Step 9: Update JS

- `app/javascript/controllers/theme_toggle_controller.js`: check for `colortheme` reference

#### Step 10: Update tests and fixtures (~50+ files)

- Rename 12 test files: `test/models/*_colortheme*_test.rb` -> `*_theme*_test.rb`
- Rename 12 fixture files: `test/fixtures/*_colortheme*.yml` -> `*_theme*.yml`
- Update content in ~25+ additional test files (integration tests, controller tests, helper tests,
  service tests, preference tests)

#### Step 11: Verify zero remaining references

```bash
grep -rn "colortheme" app/ lib/ test/ config/routes/ db/*_schema.rb
```

Should return 0 results. Old migration files in `db/*_migrate/` will still contain the old name —
that is expected and correct (migration history must not be rewritten).

Risk: HIGH (12 model files + ~25 controller / concern / helper / view / test files + 3 DB
migrations).

---

## Verification (after all phases)

```bash
bundle exec rails db:migrate
bundle exec rails test
bundle exec rubocop
bundle exec erb_lint .
vp check
# Confirm no stale references remain:
grep -rn "Accountably\|CatTag\|ConsumeOnceToken\|HealthsController\|colortheme" \
  app/ lib/ test/ config/routes/
```

## Items explicitly left unchanged

| Item                                | Reason                                                  |
| ----------------------------------- | ------------------------------------------------------- |
| `ins/`, `outs/`, `ups/` (view dirs) | Intentionally kept to avoid routing accidents           |
| `googles/`, `apples/` (view dirs)   | Rails auto-pluralizes `resource :google` — convention   |
| `roots_controller.rb`               | Maps to Rails `root to:` — acceptable tradeoff          |
| `io_keys.rb`                        | Abbreviated but functional, meaning is clear in context |
| Migration dir singular/plural mix   | Rails convention, cannot change                         |
