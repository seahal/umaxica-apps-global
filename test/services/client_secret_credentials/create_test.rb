# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class ClientSecretCredentialsCreateTest < ActiveSupport::TestCase
  fixtures :client_statuses, :client_email_statuses

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
  end

  test "creates secret_credential with auto-generated raw secret_credential" do
    params = { name: "api-key-1", enabled: true }

    result = ClientSecretCredentialsCreate.call(actor: @user, user: @user, params: params)

    assert_predicate result.secret_credential, :persisted?
    assert_predicate result.raw_secret_credential, :present?
    assert_equal "api-key-1", result.secret_credential.name
    assert_predicate result.secret_credential, :enabled?
  end

  test "creates secret_credential with provided raw secret_credential" do
    params = { name: "api-key-2", enabled: true }
    provided_secret_credential = ClientSecretCredential.generate_raw_secret_credential

    result = ClientSecretCredentialsCreate.call(
      actor: @user,
      user: @user,
      params: params,
      raw_secret_credential: provided_secret_credential,
    )

    assert_equal provided_secret_credential, result.raw_secret_credential
  end

  test "creates secret_credential with enabled=false as revoked" do
    params = { name: "disabled-key", enabled: false }

    result = ClientSecretCredentialsCreate.call(actor: @user, user: @user, params: params)

    assert_predicate result.secret_credential, :revoked?
  end

  test "creates secret_credential with enabled=true as active" do
    params = { name: "enabled-key", enabled: true }

    result = ClientSecretCredentialsCreate.call(actor: @user, user: @user, params: params)

    assert_predicate result.secret_credential, :active?
  end

  test "strips whitespace from name parameter" do
    params = { name: "  test-name-with-spaces  ", enabled: true }

    result = ClientSecretCredentialsCreate.call(actor: @user, user: @user, params: params)

    assert_equal "test-name-with-spaces", result.secret_credential.name
  end
end
