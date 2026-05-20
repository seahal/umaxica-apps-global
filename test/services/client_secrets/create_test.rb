# typed: false
# frozen_string_literal: true

require "test_helper"

class ClientSecrets::CreateTest < ActiveSupport::TestCase
  fixtures :client_statuses, :client_email_statuses

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
  end

  test "creates secret with auto-generated raw secret" do
    params = { name: "api-key-1", enabled: true }

    result = ClientSecrets::Create.call(actor: @user, user: @user, params: params)

    assert_predicate result.secret, :persisted?
    assert_predicate result.raw_secret, :present?
    assert_equal "api-key-1", result.secret.name
    assert_predicate result.secret, :enabled?
  end

  test "creates secret with provided raw secret" do
    params = { name: "api-key-2", enabled: true }
    provided_secret = ClientSecret.generate_raw_secret

    result = ClientSecrets::Create.call(
      actor: @user,
      user: @user,
      params: params,
      raw_secret: provided_secret,
    )

    assert_equal provided_secret, result.raw_secret
  end

  test "creates secret with enabled=false as revoked" do
    params = { name: "disabled-key", enabled: false }

    result = ClientSecrets::Create.call(actor: @user, user: @user, params: params)

    assert_predicate result.secret, :revoked?
  end

  test "creates secret with enabled=true as active" do
    params = { name: "enabled-key", enabled: true }

    result = ClientSecrets::Create.call(actor: @user, user: @user, params: params)

    assert_predicate result.secret, :active?
  end

  test "strips whitespace from name parameter" do
    params = { name: "  test-name-with-spaces  ", enabled: true }

    result = ClientSecrets::Create.call(actor: @user, user: @user, params: params)

    assert_equal "test-name-with-spaces", result.secret.name
  end
end
