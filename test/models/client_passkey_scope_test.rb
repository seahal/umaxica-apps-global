# typed: false
# frozen_string_literal: true

require "test_helper"

class ClientPasskeyScopeTest < ActiveSupport::TestCase
  setup do
    @user = create_verified_user_with_email(email_address: "passkey_scope_test@example.com")

    @active_passkey = ClientPasskey.create!(
      user: @user,
      webauthn_id: "active_id",
      external_id: SecureRandom.uuid,
      public_key: "pk",
      description: "Active Key",
      status_id: ClientPasskeyStatus::ACTIVE,
    )

    @inactive_passkey = ClientPasskey.create!(
      user: @user,
      webauthn_id: "inactive_id",
      external_id: SecureRandom.uuid,
      public_key: "pk",
      description: "Inactive Key",
      status_id: ClientPasskeyStatus::DISABLED,
    )
  end

  test "active scope includes only active passkeys" do
    assert_includes ClientPasskey.active, @active_passkey
    assert_not_includes ClientPasskey.active, @inactive_passkey
  end
end
