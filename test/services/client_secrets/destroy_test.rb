# typed: false
# frozen_string_literal: true

require "test_helper"

class ClientSecrets::DestroyTest < ActiveSupport::TestCase
  fixtures :client_statuses, :client_email_statuses, :client_secret_statuses

  setup do
    @user = Client.create!(
      status_id: ClientStatus::NOTHING,
      public_id: "secret_user_#{SecureRandom.hex(4)}",
    )
    ClientEmail.create!(
      user: @user,
      address: "secret-test-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    @secret = ClientSecret.create!(
      user: @user,
      name: "Test Secret",
      password: ClientSecret.generate_raw_secret,
      user_secret_status_id: ClientSecretStatus::ACTIVE,
    )
  end

  test "destroys user secret" do
    assert_difference("ClientSecret.count", -1) do
      ClientSecrets::Destroy.call(actor: @user, secret: @secret)
    end
  end

  test "creates ClientChronicle audit when actor is Client" do
    assert_difference("ClientChronicle.count", 1) do
      ClientSecrets::Destroy.call(actor: @user, secret: @secret)
    end

    activity = ClientChronicle.last

    assert_equal ClientChronicleEvent::USER_SECRET_REMOVED, activity.event_id
    assert_equal @user, activity.actor
    assert_equal @secret.id.to_s, activity.subject_id
  end
end
