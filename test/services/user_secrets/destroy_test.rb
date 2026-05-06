# typed: false
# frozen_string_literal: true

require "test_helper"

class UserSecrets::DestroyTest < ActiveSupport::TestCase
  fixtures :user_statuses, :user_email_statuses, :user_secret_statuses

  setup do
    @user = User.create!(
      status_id: UserStatus::NOTHING,
      public_id: "secret_user_#{SecureRandom.hex(4)}",
    )
    UserEmail.create!(
      user: @user,
      address: "secret-test-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: UserEmailStatus::VERIFIED,
    )
    @secret = UserSecret.create!(
      user: @user,
      name: "Test Secret",
      password: UserSecret.generate_raw_secret,
      user_secret_status_id: UserSecretStatus::ACTIVE,
    )
  end

  test "destroys user secret" do
    assert_difference("UserSecret.count", -1) do
      UserSecrets::Destroy.call(actor: @user, secret: @secret)
    end
  end

  test "creates UserChronicle audit when actor is User" do
    assert_difference("UserChronicle.count", 1) do
      UserSecrets::Destroy.call(actor: @user, secret: @secret)
    end

    activity = UserChronicle.last

    assert_equal UserChronicleEvent::USER_SECRET_REMOVED, activity.event_id
    assert_equal @user, activity.actor
    assert_equal @secret.id.to_s, activity.subject_id
  end
end
