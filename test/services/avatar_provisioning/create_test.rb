# typed: false
# frozen_string_literal: true

require "test_helper"

class AvatarProvisioningCreateTest < ActiveSupport::TestCase
  test "creates avatar handle persona binding and owner assignment in one transaction" do
    user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: user)
    bootstrap.avatar.current_avatar_persona_binding.revoke!(force: true)

    assert_difference -> { Avatar.count }, 1 do
      assert_difference -> { Handle.count }, 1 do
        assert_difference -> { AvatarPersonaBinding.active.count }, 1 do
          assert_difference -> { AvatarAssignment.where(role: "owner").count }, 1 do
            result = AvatarProvisioning::Create.call(
              actor: user,
              subject_type: :persona,
              subject: bootstrap.account,
              avatar_params: { moniker: "Provisioned Avatar" },
              handle_params: { handle: "provisioned" },
              organization_public_id: bootstrap.collective.public_id,
            )

            assert_predicate result, :success?
            assert_equal "Provisioned Avatar", result.avatar.moniker
            assert_equal "active", result.avatar.lifecycle_state.key
            assert_equal bootstrap.account, result.binding.persona
            assert_equal user, result.assignment.user
            assert_equal result.avatar, bootstrap.account.reload.current_avatar
          end
        end
      end
    end
  end

  test "handle conflict rolls back the avatar graph" do
    user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: user)
    bootstrap.avatar.current_avatar_persona_binding.revoke!(force: true)
    Handle.create!(handle: "conflict-aaaaaaaa", cooldown_until: Time.current, is_system: false)

    SecureRandom.stub(:alphanumeric, "AAAAAAAA") do
      assert_no_difference -> {
        Avatar.count + AvatarPersonaBinding.count + AvatarAssignment.count
      } do
        result = AvatarProvisioning::Create.call(
          actor: user,
          subject_type: :persona,
          subject: bootstrap.account,
          avatar_params: { moniker: "Conflict Avatar" },
          handle_params: { handle: "conflict" },
          organization_public_id: bootstrap.collective.public_id,
        )

        assert_not_predicate result, :success?
      end
    end
  end

  test "assignment failure rolls back avatar handle and binding" do
    user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: user)
    bootstrap.avatar.current_avatar_persona_binding.revoke!(force: true)

    assert_no_difference -> {
      Avatar.count + Handle.count + AvatarPersonaBinding.count + AvatarAssignment.count
    } do
      result = AvatarProvisioning::Create.call(
        actor: user,
        subject_type: :persona,
        subject: bootstrap.account,
        avatar_params: { moniker: "Bad Assignment" },
        handle_params: { handle: "bad-assignment" },
        assignment_role: "not-a-role",
        organization_public_id: bootstrap.collective.public_id,
      )

      assert_not_predicate result, :success?
    end
  end

  test "invalid avatar params leave no partial rows" do
    user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: user)
    bootstrap.avatar.current_avatar_persona_binding.revoke!(force: true)

    assert_no_difference -> {
      Avatar.count + Handle.count + AvatarPersonaBinding.count + AvatarAssignment.count
    } do
      result = AvatarProvisioning::Create.call(
        actor: user,
        subject_type: :persona,
        subject: bootstrap.account,
        avatar_params: { moniker: "" },
        handle_params: { handle: "invalid-avatar" },
        organization_public_id: bootstrap.collective.public_id,
      )

      assert_not_predicate result, :success?
    end
  end

  test "legacy client id is not the canonical subject relation" do
    user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: user)
    bootstrap.avatar.current_avatar_persona_binding.revoke!(force: true)

    result = AvatarProvisioning::Create.call(
      actor: user,
      subject_type: :persona,
      subject: bootstrap.account,
      avatar_params: { moniker: "Compatibility Avatar" },
      handle_params: { handle: "compatibility" },
      organization_public_id: bootstrap.collective.public_id,
    )

    assert_predicate result, :success?
    assert_equal user.id, result.avatar.client_id
    assert_equal bootstrap.account, result.avatar.current_persona
    assert_equal result.avatar, bootstrap.account.reload.current_avatar
  end
end
