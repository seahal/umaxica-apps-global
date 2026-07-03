# frozen_string_literal: true

class AddAvatarAuthorityLifecycleConstraints < ActiveRecord::Migration[8.2]
  def up
    add_check_constraint(
      :avatar_memberships,
      "valid_from <= valid_to",
      name: "chk_avatar_memberships_valid_period",
      validate: false,
    ) unless check_constraint_exists?(:avatar_memberships, name: "chk_avatar_memberships_valid_period")

    add_check_constraint(
      :avatar_persona_bindings,
      "revoked_at IS NULL OR revoked_at >= assigned_at",
      name: "chk_avatar_persona_bindings_revoked_after_assigned",
      validate: false,
    ) unless check_constraint_exists?(:avatar_persona_bindings, name: "chk_avatar_persona_bindings_revoked_after_assigned")

    add_check_constraint(
      :avatar_lifecycle_events,
      "from_state_key <> to_state_key",
      name: "chk_avatar_lifecycle_events_state_changes",
      validate: false,
    ) unless check_constraint_exists?(:avatar_lifecycle_events, name: "chk_avatar_lifecycle_events_state_changes")

    add_foreign_key(
      :avatar_lifecycle_events,
      :avatar_lifecycle_states,
      column: :from_state_key,
      primary_key: :key,
      validate: false,
      name: "fk_avatar_lifecycle_events_from_state_key",
    ) unless foreign_key_exists?(:avatar_lifecycle_events, name: "fk_avatar_lifecycle_events_from_state_key")

    add_foreign_key(
      :avatar_lifecycle_events,
      :avatar_lifecycle_states,
      column: :to_state_key,
      primary_key: :key,
      validate: false,
      name: "fk_avatar_lifecycle_events_to_state_key",
    ) unless foreign_key_exists?(:avatar_lifecycle_events, name: "fk_avatar_lifecycle_events_to_state_key")
  end

  def down
    remove_foreign_key(:avatar_lifecycle_events, name: "fk_avatar_lifecycle_events_to_state_key")
    remove_foreign_key(:avatar_lifecycle_events, name: "fk_avatar_lifecycle_events_from_state_key")
    remove_check_constraint(:avatar_lifecycle_events, name: "chk_avatar_lifecycle_events_state_changes")
    remove_check_constraint(:avatar_persona_bindings, name: "chk_avatar_persona_bindings_revoked_after_assigned")
    remove_check_constraint(:avatar_memberships, name: "chk_avatar_memberships_valid_period")
  end
end
