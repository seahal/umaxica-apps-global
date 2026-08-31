# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentityCeremonyContractGuardTest < ActiveSupport::TestCase
  test "ceremony contracts reject blank invalid and unsafe headers" do
    [
      [IdentityStepUpCeremonyContract, IdentityStepUpCeremonyContract::Error],
      [IdentityTelephoneCeremonyContract, IdentityTelephoneCeremony::Error],
      [IdentityPasskeyCeremonyContract, IdentityPasskeyCeremonyContract::Error],
      [IdentityTotpCeremonyContract, IdentityTotpCeremonyContract::Error],
      [IdentitySocialCeremonyContract, IdentitySocialCeremonyContract::Error],
      [IdentitySecretCredentialCeremonyContract, IdentitySecretCredentialCeremonyContract::Error],
      [IdentityEmailCeremonyContract, IdentityEmailCeremonyContract::Error],
    ].each do |contract, error_class|
      assert_raises(error_class) { contract.validate_header!({}, expected_type: "grant") }
      assert_raises(error_class) { contract.validate_header!(nil, expected_type: "grant") }
      assert_raises(error_class) do
        contract.validate_header!({ "alg" => "HS256", "typ" => "grant", "kid" => "k" }, expected_type: "grant")
      end
      assert_raises(error_class) do
        contract.validate_header!({ "alg" => "ES384", "typ" => "other", "kid" => "k" }, expected_type: "grant")
      end
      assert_raises(error_class) do
        contract.validate_header!({ "alg" => "ES384", "typ" => "grant", "kid" => "" }, expected_type: "grant")
      end
      assert_raises(error_class) do
        contract.validate_header!(
          { "alg" => "ES384", "typ" => "grant", "kid" => "k", "jku" => "https://evil.example" },
          expected_type: "grant",
        )
      end
      contract.validate_header!({ "alg" => "ES384", "typ" => "grant", "kid" => "k" }, expected_type: "grant")
    end
  end

  test "ceremony contracts reject unknown claims non integer timestamps and expired values" do
    now = Time.zone.local(2026, 1, 2, 3, 4, 5)
    [
      [IdentityStepUpCeremonyContract, IdentityStepUpCeremonyContract::Error],
      [IdentityTelephoneCeremonyContract, IdentityTelephoneCeremony::Error],
      [IdentityPasskeyCeremonyContract, IdentityPasskeyCeremonyContract::Error],
      [IdentityTotpCeremonyContract, IdentityTotpCeremonyContract::Error],
      [IdentitySocialCeremonyContract, IdentitySocialCeremonyContract::Error],
      [IdentitySecretCredentialCeremonyContract, IdentitySecretCredentialCeremonyContract::Error],
      [IdentityEmailCeremonyContract, IdentityEmailCeremonyContract::Error],
    ].each do |contract, error_class|
      assert_raises(error_class) do
        contract.validate_keys!({ "unexpected" => "x" }, allowed: %w(iss aud))
      end
      assert_raises(error_class) { contract.validate_timestamp!({ "iat" => "soon" }, "iat") }
      assert_raises(error_class) do
        contract.validate_future_timestamp!({ "exp" => now.to_i - 1 }, "exp", now: now)
      end
      assert_raises(error_class) do
        contract.validate_future_timestamp!({ "exp" => "soon" }, "exp", now: now)
      end
      assert_raises(error_class) { contract.validate_binding!({ "actor_ref" => "", "session_ref" => "s" }) }
      assert_raises(error_class) { contract.validate_binding!({ "actor_ref" => "a", "session_ref" => "" }) }
      contract.validate_timestamp!({ "iat" => now.to_i }, "iat")
      contract.validate_future_timestamp!({ "exp" => now.to_i + 30 }, "exp", now: now)
    end
  end
end
