# typed: false
# frozen_string_literal: true

require "test_helper"

# Same contract boundary as the telephone ceremony: a token that cannot be read
# at all is a contract error for this surface, not a leaked JWT library error.
class IdentitySecretCredentialCeremonyContractTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "an unreadable token is reported as a ceremony contract error" do
    error =
      assert_raises(IdentitySecretCredentialCeremonyContract::Error) do
        IdentitySecretCredentialCeremonyContract.decode_unverified_payload("not-a-jwt")
      end

    assert_match(/token is invalid/, error.message)
  end
end
