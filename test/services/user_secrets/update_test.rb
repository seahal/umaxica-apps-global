# typed: false
# frozen_string_literal: true

require "test_helper"

class UserSecrets::UpdateTest < ActiveSupport::TestCase
  fixtures :users, :user_secrets, :user_secret_statuses

  setup do
    @user = users(:one)
    @secret = user_secrets(:one)
  end

  test "updates secret name" do
    result = UserSecrets::Update.call(
      actor: @user,
      secret: @secret,
      params: { name: "Updated Secret Name" },
    )

    assert_predicate result.secret, :persisted?
    assert_equal "Updated Secret Name", result.secret.name
  end

  test "updates secret status to active when enabled is true" do
    @secret.update!(user_secret_status_id: UserSecretStatus::REVOKED)

    result = UserSecrets::Update.call(
      actor: @user,
      secret: @secret,
      params: { enabled: true },
    )

    assert_equal UserSecretStatus::ACTIVE, result.secret.user_secret_status_id
  end

  test "updates secret status to revoked when enabled is false" do
    @secret.update!(user_secret_status_id: UserSecretStatus::ACTIVE)

    result = UserSecrets::Update.call(
      actor: @user,
      secret: @secret,
      params: { enabled: false },
    )

    assert_equal UserSecretStatus::REVOKED, result.secret.user_secret_status_id
  end

  test "updates both name and status" do
    @secret.update!(user_secret_status_id: UserSecretStatus::REVOKED)

    result = UserSecrets::Update.call(
      actor: @user,
      secret: @secret,
      params: { name: "New Name", enabled: true },
    )

    assert_equal "New Name", result.secret.name
    assert_equal UserSecretStatus::ACTIVE, result.secret.user_secret_status_id
  end

  test "creates user activity audit record" do
    assert_difference -> { UserChronicle.count } do
      UserSecrets::Update.call(
        actor: @user,
        secret: @secret,
        params: { name: "Audit Test" },
      )
    end

    activity = UserChronicle.last

    assert_equal @user, activity.actor
    assert_equal "UserSecret", activity.subject_type
    assert_equal @secret.id.to_s, activity.subject_id
    assert_equal UserChronicleEvent::USER_SECRET_UPDATED, activity.event_id
  end

  test "handles string true for enabled" do
    @secret.update!(user_identity_secret_status_id: UserSecretStatus::REVOKED)

    result = UserSecrets::Update.call(
      actor: @user,
      secret: @secret,
      params: { enabled: "true" },
    )

    assert_equal UserSecretStatus::ACTIVE, result.secret.user_identity_secret_status_id
  end

  test "handles string false for enabled" do
    @secret.update!(user_secret_status_id: UserSecretStatus::ACTIVE)

    result = UserSecrets::Update.call(
      actor: @user,
      secret: @secret,
      params: { enabled: "false" },
    )

    assert_equal UserSecretStatus::REVOKED, result.secret.user_secret_status_id
  end

  test "strips whitespace from name" do
    result = UserSecrets::Update.call(
      actor: @user,
      secret: @secret,
      params: { name: "  Test Name  " },
    )

    assert_equal "Test Name", result.secret.name
  end

  test "does not update name when blank" do
    original_name = @secret.name

    result = UserSecrets::Update.call(
      actor: @user,
      secret: @secret,
      params: { name: "   " },
    )

    assert_equal original_name, result.secret.name
  end
end
