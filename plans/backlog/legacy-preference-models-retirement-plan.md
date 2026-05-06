# Legacy Preference Models Retirement Plan

## Issue

GitHub #691

## Current State

### Legacy Models (To be retired)

These are the old domain-scoped preference models that need to be retired:

#### App Domain (Principal Database)

- `AppPreference` - Main preference container
- `AppPreferenceLanguage`, `AppPreferenceTimezone`, `AppPreferenceRegion`,
  `AppPreferenceColortheme`, `AppPreferenceCookie` - Sub-preferences
- `AppPreferenceLanguageOption`, `AppPreferenceTimezoneOption`, `AppPreferenceRegionOption`,
  `AppPreferenceColorthemeOption` - Reference options
- `AppPreferenceStatus`, `AppPreferenceBindingMethod`, `AppPreferenceDbscStatus` - Status/behavior
- `AppPreferenceActivity`, `AppPreferenceActivityEvent`, `AppPreferenceActivityLevel` - Audit

#### Com Domain (Commerce Database)

- `ComPreference` and all related models (same pattern as App)

#### Org Domain (Operator Database)

- `OrgPreference` and all related models (same pattern as App)

#### Setting Domain (Setting Database)

- `SettingPreference` and all related models

### New Models (Target State)

These are the actor-scoped preference models that replace the legacy ones:

- `UserPreference` - For end users (Principal DB)
  - `UserPreferenceLanguage`, `UserPreferenceTimezone`, `UserPreferenceRegion`,
    `UserPreferenceColortheme`
  - Associated option tables
- `StaffPreference` - For staff/operators (Principal DB)
  - `StaffPreferenceLanguage`, `StaffPreferenceTimezone`, `StaffPreferenceRegion`,
    `StaffPreferenceColortheme`
  - Associated option tables
- `CustomerPreference` - For customers (Guest DB)
  - Related sub-preference models

## Migration Strategy

### Phase 1: Data Mapping Analysis

1. Map all legacy preference data to new model structure
2. Identify unique constraints and relationships
3. Determine cookie/consent handling migration path

### Phase 2: Dual-Write Implementation

1. Implement writes to both legacy and new models
2. Add feature flags to control read paths
3. Monitor consistency between old and new

### Phase 3: Read Path Migration

1. Migrate controllers to use new preference models
2. Update helpers and views
3. Test all preference-related flows

### Phase 4: Legacy Cleanup

1. Remove dual-write logic
2. Archive legacy data
3. Drop legacy tables and models

## Blockers/Risks

- Cookie handling logic may be tightly coupled with legacy models
- Preference inheritance between domains needs clarification
- Audit trail continuity must be maintained
- Migration downtime for preference-heavy operations

## Acceptance Criteria

- [ ] All preference reads use new models
- [ ] No writes to legacy models
- [ ] Legacy tables archived/dropped
- [ ] Cookie/consent functionality preserved
- [ ] Audit trail maintained
- [ ] Zero data loss verified
