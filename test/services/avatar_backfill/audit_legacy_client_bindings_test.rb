# typed: false
# frozen_string_literal: true

require "test_helper"

module AvatarBackfill
  class AuditLegacyClientBindingsTest < ActiveSupport::TestCase
    setup do
      [ClientStatus, ClientVisibility, ClientIdentityState, HandleStatus].each do |klass|
        klass.ensure_defaults! if klass.respond_to?(:ensure_defaults!)
      end
      AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL)
      ensure_lifecycle_state("active", "Active", 10, can_create_content: true, visible_by_default: true,
                                                  editable_by_owner: true, restorable_by_owner: false,
                                                  followable: true, group_attachable: true, discoverable: true,
                                                  moderation_visible: true, terminal: false)
      ensure_lifecycle_state("deleted", "Deleted", 50, can_create_content: false, visible_by_default: false,
                                                    editable_by_owner: false, restorable_by_owner: false,
                                                    followable: false, group_attachable: false, discoverable: false,
                                                    moderation_visible: true, terminal: true)
    end

    test "classifies safe legacy client binding candidates without mutating rows" do
      client = create_client
      persona = create_persona(client)
      avatar = create_avatar(client: client)

      assert_no_difference -> { AvatarPersonaBinding.count } do
        result = AuditLegacyClientBindings.call
        detail = result.details.find { |row| row[:avatar_id] == avatar.id }

        assert_equal "safe_to_backfill", detail.fetch(:conflict_bucket)
        assert_equal "Persona", detail.fetch(:resolved_subject_type)
        assert_equal persona.id, detail.fetch(:resolved_subject_id)
        assert_predicate detail.fetch(:reason), :present?
        assert_predicate detail.fetch(:recommended_next_action), :present?
        assert_equal 1, result.summary.fetch(:safe_to_backfill_count)
      end
    end

    test "classifies already bound consistent candidates" do
      client = create_client
      persona = create_persona(client)
      avatar = create_avatar(client: client)
      AvatarPersonaBinding.create!(avatar: avatar, persona: persona)

      detail = AuditLegacyClientBindings.call.details.find { |row| row[:avatar_id] == avatar.id }

      assert_equal "already_bound_consistent", detail.fetch(:conflict_bucket)
      assert_equal "AvatarPersonaBinding", detail.fetch(:existing_binding_type)
    end

    test "classifies already bound inconsistent candidates" do
      client = create_client
      create_persona(client)
      other_client = create_client
      other_persona = create_persona(other_client)
      avatar = create_avatar(client: client)
      AvatarPersonaBinding.create!(avatar: avatar, persona: other_persona)

      detail = AuditLegacyClientBindings.call.details.find { |row| row[:avatar_id] == avatar.id }

      assert_equal "already_bound_inconsistent", detail.fetch(:conflict_bucket)
    end

    test "classifies subject that already has another active binding" do
      client = create_client
      persona = create_persona(client)
      bound_avatar = create_avatar(client: nil)
      AvatarPersonaBinding.create!(avatar: bound_avatar, persona: persona)
      legacy_avatar = create_avatar(client: client)

      detail = AuditLegacyClientBindings.call.details.find { |row| row[:avatar_id] == legacy_avatar.id }

      assert_equal "subject_already_has_active_binding", detail.fetch(:conflict_bucket)
    end

    test "classifies multiple legacy avatars for one subject" do
      client = create_client
      create_persona(client)
      first_avatar = create_avatar(client: client)
      create_avatar(client: client)

      detail = AuditLegacyClientBindings.call.details.find { |row| row[:avatar_id] == first_avatar.id }

      assert_equal "multiple_legacy_avatars_for_subject", detail.fetch(:conflict_bucket)
    end

    test "classifies missing client" do
      avatar = create_avatar(client_id: 987_654_321)

      detail = AuditLegacyClientBindings.call.details.find { |row| row[:avatar_id] == avatar.id }

      assert_equal "missing_client", detail.fetch(:conflict_bucket)
    end

    test "classifies unresolved subject" do
      client = create_client
      avatar = create_avatar(client: client)

      detail = AuditLegacyClientBindings.call.details.find { |row| row[:avatar_id] == avatar.id }

      assert_equal "unresolved_subject", detail.fetch(:conflict_bucket)
    end

    test "classifies deleted avatar as skipped" do
      client = create_client
      create_persona(client)
      avatar = create_avatar(client: client, lifecycle_state: AvatarLifecycleState.find_by!(key: "deleted"))

      detail = AuditLegacyClientBindings.call.details.find { |row| row[:avatar_id] == avatar.id }

      assert_equal "deleted_avatar_skipped", detail.fetch(:conflict_bucket)
    end

    test "summary counts include all required buckets" do
      client = create_client
      create_persona(client)
      create_avatar(client: client)

      summary = AuditLegacyClientBindings.call.summary

      AuditLegacyClientBindings::BUCKETS.each do |bucket|
        assert_includes summary, :"#{bucket}_count"
      end
      assert_equal Avatar.count, summary.fetch(:total_avatars_scanned)
    end

    private

    def create_client
      Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    end

    def ensure_lifecycle_state(key, title, sort_order, **attributes)
      AvatarLifecycleState.find_or_create_by!(key: key) do |state|
        state.title = title
        state.sort_order = sort_order
        attributes.each { |name, value| state.public_send("#{name}=", value) }
      end
    end

    def create_persona(client)
      identity = ClientIdentity.create!(
        issuer: "https://id.example.test",
        subject: "legacy-client-binding-#{SecureRandom.hex(6)}",
        audience: "acme_app",
        source_record_id: client.id,
        status_id: ClientIdentityState::ACTIVE,
      )
      Persona.create!(client_identity: identity, moniker: "Legacy Persona", title: "Legacy1")
    end

    def create_avatar(client: nil, client_id: nil, lifecycle_state: AvatarLifecycleState.find_by!(key: "active"))
      handle = Handle.create!(
        handle: "legacy-backfill-#{SecureRandom.hex(6)}",
        handle_status_id: HandleStatus::ACTIVE,
        cooldown_until: Time.current,
        is_system: false,
      )
      Avatar.create!(
        moniker: "Legacy Avatar",
        active_handle: handle,
        capability_id: AvatarCapability::NORMAL,
        client_id: client&.id || client_id,
        lifecycle_state: lifecycle_state,
        image_data: {},
      )
    end
  end
end
