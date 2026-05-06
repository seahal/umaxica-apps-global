# ADR: Remove Polymorphic Owner from SettingPreference

**Status:** Accepted

GitHub: #697

## Context

`SettingPreference` is a unified preference store in the `setting` database that currently uses
Rails polymorphic associations (`belongs_to :owner, polymorphic: true`) to represent ownership by
different entity types:

- `AppPreference` → owned by `User`
- `ComPreference` → owned by `Customer`
- `OrgPreference` → owned by `Staff`

The current schema stores ownership as `owner_type` (string) + `owner_id` (bigint). While
polymorphic associations provide flexibility, they prevent database-level foreign key constraints
and leave referential integrity entirely to application code.

During the Rails Engine migration, we identified that controller implementations are temporarily
broken, making this an opportune time to fix the underlying data model before stabilizing the API.

## Decision

Replace the polymorphic `owner` association with explicit nullable owner columns:

- `user_id` (bigint, nullable)
- `staff_id` (bigint, nullable)
- `customer_id` (bigint, nullable)

Enforce exactly-one-owner semantics at both database and application levels.

**Important Note on Foreign Keys**: Due to the multi-database architecture, foreign key constraints
cannot be added because the `setting` database cannot reference tables in the `principal` database
(users, staff, customers). Referential integrity is enforced at the application level via model
validations and the `exactly_one_owner_present` validation.

## Implementation Plan

### Phase 1: Schema Migration

1. **Add explicit owner columns** to `settings_preferences`:

   ```ruby
   add_column :settings_preferences, :user_id, :bigint, null: true
   add_column :settings_preferences, :staff_id, :bigint, null: true
   add_column :settings_preferences, :customer_id, :bigint, null: true
   ```

2. **Add indexes** for each owner column:

   ```ruby
   add_index :settings_preferences, :user_id, unique: true, where: "user_id IS NOT NULL"
   add_index :settings_preferences, :staff_id, unique: true, where: "staff_id IS NOT NULL"
   add_index :settings_preferences, :customer_id, unique: true, where: "customer_id IS NOT NULL"
   ```

3. **Add database-level exactly-one-owner constraint**:

   ```ruby
   # Using PostgreSQL check constraint
   add_check_constraint :settings_preferences,
     "(user_id IS NOT NULL)::int + (staff_id IS NOT NULL)::int + (customer_id IS NOT NULL)::int = 1",
     name: "chk_settings_preferences_exactly_one_owner"
   ```

4. **Backfill existing data** from `owner_type`/`owner_id`:

   ```ruby
   execute <<-SQL
     UPDATE settings_preferences
     SET user_id = owner_id
     WHERE owner_type = 'User';

     UPDATE settings_preferences
     SET staff_id = owner_id
     WHERE owner_type = 'Staff';

     UPDATE settings_preferences
     SET customer_id = owner_id
     WHERE owner_type = 'Customer';
   SQL
   ```

5. **Make legacy columns nullable** (for transition period):
   ```ruby
   change_column_null :settings_preferences, :owner_type, true
   change_column_null :settings_preferences, :owner_id, true
   ```

### Phase 2: Model Updates

1. **Replace polymorphic association** in `SettingPreference`:

   ```ruby
   # Remove:
   # belongs_to :owner, polymorphic: true, optional: true

   # Add:
   belongs_to :user, optional: true
   belongs_to :staff, optional: true
   belongs_to :customer, optional: true
   ```

2. **Add exactly-one-owner validation**:

   ```ruby
   validate :exactly_one_owner_present

   private

   def exactly_one_owner_present
     owners = [user_id, staff_id, customer_id].compact.size
     if owners != 1
       errors.add(:base, "must have exactly one owner (user, staff, or customer)")
     end
   end
   ```

3. **Add owner accessor method** for backward compatibility:

   ```ruby
   def owner
     user || staff || customer
   end

   def owner_type
     return "User" if user_id.present?
     return "Staff" if staff_id.present?
     return "Customer" if customer_id.present?
     nil
   end

   def owner_id
     user_id || staff_id || customer_id
   end
   ```

### Phase 3: StorageAdapter Updates

Update `Preference::StorageAdapter` to use explicit owner columns:

1. **Update `create!` method**:

   ```ruby
   def create!(attrs, preference_type:)
     owner_column = owner_column_for(preference_type)
     setting_attrs = attrs.merge(
       owner_column => attrs[:owner_id] || 0
     )
     # ... rest of create logic
   end
   ```

2. **Add owner column mapping**:

   ```ruby
   def owner_column_for(preference_type)
     case preference_type.to_s
     when "OrgPreference" then :staff_id
     when "ComPreference" then :customer_id
     else :user_id
     end
   end
   ```

3. **Update `PreferenceWrapper`** to read from new columns while maintaining interface
   compatibility.

### Phase 4: Anonymous/Bootstrap Behavior

Preserve the existing anonymous bootstrap behavior where `owner_id: 0` represents an unadopted
preference:

- ID `0` will not have a foreign key constraint (no user/staff/customer with ID 0 exists)
- The check constraint allows `0` as a valid value
- Application logic treats `0` as "anonymous/unassigned"

## Trade-offs

### Why Not Keep Polymorphic Associations?

1. **No database-level referential integrity** - orphaned records possible
2. **No cascading deletes** - must handle in application code
3. **Index bloat** - compound indexes on `(owner_type, owner_id)` are larger and less efficient
4. **Query complexity** - joins require type casting

### Why Not Use Single-Table Inheritance (STI)?

STI would require separate tables or complex type discrimination. The preference data structure is
identical across owner types; only the ownership differs.

### Why Allow NULL with Check Constraint Instead of NOT NULL?

This allows:

1. Clean migration path (add columns, backfill, then enforce)
2. Future extension (if a new owner type is added)
3. Anonymous/bootstrap records with ID 0

## Acceptance Criteria

- [ ] `SettingPreference` no longer uses `belongs_to :owner, polymorphic: true`
- [ ] Database has explicit FK columns (`user_id`, `staff_id`, `customer_id`)
- [ ] Exactly-one-owner constraint enforced at database level
- [ ] Existing data backfilled from `owner_type`/`owner_id`
- [ ] `StorageAdapter` uses explicit owner columns
- [ ] Anonymous/bootstrap behavior (`owner_id: 0`) preserved
- [ ] Tests cover each owner type and edge cases
- [ ] Legacy `owner_type`/`owner_id` columns removed (Phase 5, after rollout)

## Affected Components

- `app/models/setting_preference.rb`
- `app/services/preference/storage_adapter.rb`
- `app/services/preference/class_registry.rb` (owner type mapping)
- `app/controllers/concerns/preference/base.rb` (anonymous owner handling)
- `db/settings_migrate/` (new migration files)

## Non-Goals

- Do not change preference public API (tokens, cookies, JWT payload)
- Do not refactor audit tables (they have their own polymorphic associations)
- Do not modify legacy preference tables (AppPreference, OrgPreference, ComPreference)

## References

- Issue #697: Remove polymorphic owner from SettingPreference
- Issue #696: Similar refactoring for Treeable concern (independent work)
- `app/models/setting_preference.rb`
- `app/services/preference/storage_adapter.rb`
- `app/services/preference/class_registry.rb`
- `db/settings_migrate/20260407000001_create_unified_preferences_in_setting_db.rb`
