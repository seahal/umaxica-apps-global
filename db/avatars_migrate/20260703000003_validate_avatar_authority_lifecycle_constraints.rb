# frozen_string_literal: true

class ValidateAvatarAuthorityLifecycleConstraints < ActiveRecord::Migration[8.2]
  def up
    validate_check_constraint(:avatar_memberships, name: "chk_avatar_memberships_valid_period")
    validate_check_constraint(:avatar_persona_bindings, name: "chk_avatar_persona_bindings_revoked_after_assigned")
    validate_check_constraint(:avatar_lifecycle_events, name: "chk_avatar_lifecycle_events_state_changes")

    validate_foreign_key(:avatar_lifecycle_events, name: "fk_avatar_lifecycle_events_from_state_key")
    validate_foreign_key(:avatar_lifecycle_events, name: "fk_avatar_lifecycle_events_to_state_key")
  end

  def down
    # Validation state is not schema; constraint definitions remain in the add migration.
  end
end
