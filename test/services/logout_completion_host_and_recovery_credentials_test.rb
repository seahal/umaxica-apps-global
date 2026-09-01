# typed: false
# frozen_string_literal: true

require "test_helper"

# Both of these map an actor or an origin onto surface-specific configuration.
# The mapping has to be exhaustive: an origin that resolves to the wrong host
# sends a logout completion to another surface, and a credential class that
# resolves to the wrong relation counts, or issues, another surface's passcodes.
class LogoutCompletionHostAndRecoveryCredentialsTest < ActiveSupport::TestCase
  fixtures :operators, :operator_statuses

  def hosts = Rails.configuration.x.boot_config.fetch(:hosts)

  test "each origin surface resolves the completion host of its own realm" do
    {
      ["base", "app"] => hosts.base_service.host,
      ["base", "com"] => hosts.base_corporate.host,
      ["base", "org"] => hosts.base_staff.host,
      ["acme", "org"] => hosts.base_staff.host,
      ["core", "app"] => hosts.core_service.host,
      ["core", "com"] => hosts.core_corporate.host,
      ["core", "org"] => hosts.core_staff.host,
      ["side", "app"] => hosts.side_service.host,
      ["side", "com"] => hosts.side_corporate.host,
      ["side", "org"] => hosts.side_staff.host,
      ["palm", "app"] => hosts.palm_service.host,
    }.each do |(origin, surface), expected|
      assert_equal expected,
                   AcmeLogoutTransactionCoordinator.completion_host_for(origin_surface: origin, surface: surface),
                   "#{origin}/#{surface}"
    end
  end

  test "an origin surface with no realm is named in the error rather than defaulted" do
    error =
      assert_raises(ArgumentError) do
        AcmeLogoutTransactionCoordinator.completion_host_for(origin_surface: "martian", surface: "app")
      end

    assert_match(/unsupported logout origin surface/, error.message)
  end

  test "a logout challenge that names no transaction is reported as missing rather than raising" do
    result = AcmeLogoutTransactionCoordinator.finalize!(logout_challenge: "no-such-challenge")

    assert_equal :missing, result.status
    assert_equal "not_found", result.error
    assert_nil result.transaction
  end

  # The three surfaces keep their recovery passcodes in separate relations under
  # separate limits. A class the service was not taught raises rather than
  # answering from another surface's relation.
  test "each credential class names its own relation, limit and kind association" do
    operator = operators(:one)
    top_up = RecoveryPasscodeTopUp.new(
      actor: operator, credential_class: OperatorSecretCredential, target_count: 10, now: Time.current,
    )

    assert_equal OperatorSecretCredential::MAX_SECRETS_PER_STAFF, top_up.send(:max_secret_count_limit)
    assert_equal :staff_secret_credential_kind, top_up.send(:recovery_kind_association)
    assert_equal operator.staff_secret_credentials.to_a, top_up.send(:secret_credential_relation).to_a
  end

  test "a credential class the top-up does not serve is named in the error" do
    top_up = RecoveryPasscodeTopUp.new(
      actor: operators(:one), credential_class: OperatorToken, target_count: 10, now: Time.current,
    )

    error = assert_raises(ArgumentError) { top_up.send(:secret_credential_relation) }

    assert_match(/unsupported recovery passcode credential class/, error.message)
    assert_nil top_up.send(:max_secret_count_limit),
               "a class with no declared limit answers nil rather than raising a NameError"
    assert_nil top_up.send(:recovery_kind_association)
  end
end
