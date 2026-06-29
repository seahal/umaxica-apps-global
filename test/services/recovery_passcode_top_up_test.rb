# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class RecoveryPasscodeTopUpTest < ActiveSupport::TestCase
  setup do
    @client = create_verified_user_with_email(email_address: "recovery-top-up-#{SecureRandom.hex(4)}@example.com")
    @client.client_secret_credentials.destroy_all
  end

  test "issues ten recovery passcodes when none are active and usable" do
    result = issue_top_up_without_n_plus_one

    assert_equal 10, result.issued_count
    assert_equal 0, result.active_usable_count_before
    assert_equal 10, result.active_usable_count_after
    assert_equal 10, result.raw_values.length
    assert_equal 10, result.new_credentials.length
    assert_equal 10, result.target_count
    assert_equal 10, usable_recovery_passcode_count
    assert_equal [ClientSecretCredentialKind::RECOVERY],
                 result.new_credentials.map(&:reload).map(&:user_secret_kind_id).uniq
    assert_equal [ClientSecretCredentialStatus::ACTIVE],
                 result.new_credentials.map(&:reload).map(&:user_identity_secret_status_id).uniq
  end

  test "tops up only the shortfall when five recovery passcodes are active and usable" do
    create_client_recovery_passcodes!(@client, count: 5)

    result = issue_top_up_without_n_plus_one

    assert_equal 5, result.issued_count
    assert_equal 5, result.active_usable_count_before
    assert_equal 10, result.active_usable_count_after
    assert_equal 5, result.raw_values.length
    assert_equal 5, result.new_credentials.length
    assert_equal 10, usable_recovery_passcode_count
  end

  test "issues nothing when ten recovery passcodes are already active and usable" do
    create_client_recovery_passcodes!(@client, count: 10)

    result = issue_top_up_without_n_plus_one

    assert_equal 0, result.issued_count
    assert_equal 10, result.active_usable_count_before
    assert_equal 10, result.active_usable_count_after
    assert_empty result.raw_values
    assert_empty result.new_credentials
    assert_equal 10, usable_recovery_passcode_count
  end

  test "does not revoke existing active recovery passcodes" do
    existing = create_client_recovery_passcodes!(@client, count: 5)

    issue_top_up_without_n_plus_one

    assert_equal ClientSecretCredentialStatus::ACTIVE,
                 existing.map(&:reload).map(&:user_identity_secret_status_id).uniq.first
    assert_equal 5, existing.count { |credential| credential.reload.active? }
  end

  test "raw values authenticate against persisted hashes and are not stored in attributes" do
    result = issue_top_up_without_n_plus_one

    assert_equal result.raw_values.length, result.new_credentials.length
    result.new_credentials.zip(result.raw_values).each do |credential, raw_value|
      assert_equal credential, credential.authenticate(raw_value)
      assert_not_includes credential.reload.attributes.values, raw_value
    end
  end

  test "login and api secrets are not counted as recovery passcodes" do
    ClientSecretCredential.issue!(name: "Login", user: @client, user_secret_kind_id: ClientSecretCredentialKind::LOGIN)
    ClientSecretCredential.issue!(name: "API", user: @client, user_secret_kind_id: ClientSecretCredentialKind::API)

    result = issue_top_up_without_n_plus_one

    assert_equal 10, result.issued_count
    assert_equal 0, result.active_usable_count_before
  end

  test "respects the secret cap when there is no headroom" do
    create_client_secret_credentials!(count: ClientSecretCredential::MAX_SECRETS_PER_USER)

    result = issue_top_up_without_n_plus_one

    assert_equal 0, result.issued_count
    assert_empty result.raw_values
    assert_equal ClientSecretCredential::MAX_SECRETS_PER_USER, @client.client_secret_credentials.count
  end

  private

  def create_client_recovery_passcodes!(client, count:)
    count.times.map do |index|
      ClientSecretCredential.issue!(
        name: "Recovery #{index}",
        user: client,
        user_secret_kind_id: ClientSecretCredentialKind::RECOVERY,
        status: :active,
      ).first
    end
  end

  def create_client_secret_credentials!(count:)
    count.times do |index|
      ClientSecretCredential.issue!(
        name: "Secret #{index}",
        user: @client,
        user_secret_kind_id: ClientSecretCredentialKind::LOGIN,
        status: :active,
      )
    end
  end

  def issue_top_up_without_n_plus_one
    Prosopite.pause do
      Prosopite.scan do
        RecoveryPasscodeTopUp.call(actor: @client, credential_class: ClientSecretCredential)
      end
    end
  end

  def usable_recovery_passcode_count
    SignRecoveryPasscodeRequirement.usable_unused_count(
      actor: @client,
      credential_class: ClientSecretCredential,
    )
  end
end
