# typed: false
# frozen_string_literal: true

require "test_helper"

class ClientSecretCredentialsDestroyTest < ActiveSupport::TestCase
  fixtures :client_statuses, :client_email_statuses, :client_secret_credential_statuses

  setup do
    @user = Client.create!(
      status_id: ClientStatus::NOTHING,
      public_id: "scu_#{SecureRandom.hex(4)}",
    )
    ClientEmail.create!(
      user: @user,
      address: "secret_credential-test-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    @secret_credential = ClientSecretCredential.create!(
      user: @user,
      name: "Test Secret",
      password: ClientSecretCredential.generate_raw_secret_credential,
      user_secret_status_id: ClientSecretCredentialStatus::ACTIVE,
    )
  end

  test "destroys user secret_credential" do
    assert_difference("ClientSecretCredential.count", -1) do
      ClientSecretCredentialsDestroy.call(actor: @user, secret_credential: @secret_credential)
    end
  end

  test "creates ClientChronicle audit when actor is Client" do
    assert_difference("ClientChronicle.count", 1) do
      ClientSecretCredentialsDestroy.call(actor: @user, secret_credential: @secret_credential)
    end

    activity = ClientChronicle.last

    assert_equal ClientChronicleEvent::USER_SECRET_REMOVED, activity.event_id
    assert_equal @user, activity.actor
    assert_equal @secret_credential.id.to_s, activity.subject_id
  end
end
