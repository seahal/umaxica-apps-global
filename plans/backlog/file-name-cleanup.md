# Refactor: File Name Cleanup

## Context

Several file names in this codebase have problematic English: grammatically wrong words, unclear
abbreviations, or semantically strange pluralization. This refactor corrects 6 naming issues without
changing functionality.

## Changes (ordered by execution sequence)

### Phase 1: Dead code removal

**Delete `stagings` orphan view**

- Delete `app/views/core/com/stagings/show.html.erb`
- No controller, no route, no references anywhere. Confirmed dead code.
- Risk: none

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

**2b: `cat_tag` -> `category_tag`**

"cat" reads like the animal. This abbreviation of "category_tag" is unclear.

Files to change:

| Action        | Path                                                                                            |
| ------------- | ----------------------------------------------------------------------------------------------- |
| Rename + edit | `app/models/concerns/cat_tag.rb` -> `category_tag.rb` (`module CatTag` -> `module CategoryTag`) |
| Edit          | `app/models/app_document_category.rb` line 27: `include ::CatTag` -> `include ::CategoryTag`    |
| Edit          | `app/models/app_document_tag.rb` line 27: same                                                  |
| Edit          | `app/models/com_document_category.rb` line 27: same                                             |
| Edit          | `app/models/com_document_tag.rb` line 27: same                                                  |
| Edit          | `app/models/org_document_category.rb` line 27: same                                             |
| Edit          | `app/models/org_document_tag.rb` line 27: same                                                  |
| Edit          | `app/models/org_timeline_category.rb` line 28: same                                             |
| Edit          | `app/models/org_timeline_tag.rb` line 27: same                                                  |

Risk: low (9 files, concern is empty — no behavior change possible)

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

**Controller files to rename (24 files)**

All `healths_controller.rb` -> `health_controller.rb`, class `HealthsController` ->
`HealthController`:

- `app/controllers/acme/{app,com,org}/healths_controller.rb` (3)
- `app/controllers/acme/{app,com,org}/edge/v0/healths_controller.rb` (3)
- `app/controllers/core/{app,com,org}/healths_controller.rb` (3)
- `app/controllers/core/{app,com,org}/edge/v0/healths_controller.rb` (3)
- `app/controllers/docs/{app,com,org}/healths_controller.rb` (3)
- `app/controllers/docs/{app,com,org}/edge/v0/healths_controller.rb` (3)
- `app/controllers/sign/{app,com,org}/healths_controller.rb` (3)
- `app/controllers/sign/app/edge/v0/healths_controller.rb`
- `app/controllers/sign/org/edge/v0/healths_controller.rb`
- `app/controllers/sign/app/web/v0/healths_controller.rb`

**Route files to update (4 files, 24 route lines)**

In `config/routes/{acme,core,docs,sign}.rb`, every occurrence of:

```ruby
resource :health, only: :show
```

becomes:

```ruby
resource :health, only: :show, controller: "health"
```

**View directory to rename (1 directory)**

- `app/views/sign/app/web/v0/healths/` -> `health/`

**Test files to rename (~21 files)**

All `healths_controller_test.rb` -> `health_controller_test.rb`, update class names inside.

**Additional test file to update**

- `test/controllers/core/controller_inheritance_test.rb` lines 34, 36: `HealthsController` ->
  `HealthController`

Risk: medium (~51 files, no DB impact)

---

### Phase 4: Database-impacting rename (largest change, do last)

**`colortheme` -> `theme`**

"Colortheme" is a compound word missing the underscore separator. The user decided to shorten it to
just "theme" since the preference context already implies color.

494 occurrences across 130 files. 12+ DB tables across 4 databases.

#### Step 1: DB migrations (4 new migration files)

Create one migration per database using `rename_table`. Check for explicitly named indexes and
foreign keys that also need renaming.

| Database  | Migration dir            | Tables to rename                                                                         |
| --------- | ------------------------ | ---------------------------------------------------------------------------------------- |
| principal | `db/principals_migrate/` | `{app,staff,user}_preference_colortheme{s,_options}` -> `*_theme{s,_options}` (6 tables) |
| commerce  | `db/commerces_migrate/`  | `{app,com}_preference_colortheme{s,_options}` -> `*_theme{s,_options}` (4 tables)        |
| operator  | `db/operators_migrate/`  | `org_preference_colortheme{s,_options}` -> `*_theme{s,_options}` (2 tables)              |
| guest     | `db/guests_migrate/`     | `customer_preference_colortheme{s,_options}` -> `*_theme{s,_options}` (2 tables)         |

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

- `app/helpers/docs/common_helper.rb`: `get_colortheme` -> `get_theme`
- `app/helpers/sign/common_helper.rb`: `get_colortheme` -> `get_theme`

#### Step 7: Update views (6 files)

- `app/views/sign/{app,com,org}/preference/themes/edit.html.erb`: `@preference_colortheme` ->
  `@preference_theme`, param scope names
- `app/views/acme/{app,com,org}/preference/themes/edit.html.erb`: same

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

Risk: HIGH (130 files, 4 DB migrations)

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
