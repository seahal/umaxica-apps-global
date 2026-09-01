# typed: false
# frozen_string_literal: true

require "test_helper"

# The unverified decode runs before any signature check, on a token that arrived
# from another surface. A token the JWT parser cannot read has to surface as the
# ceremony contract's own error, not as a raw JWT::DecodeError that callers do
# not rescue.
class IdentityTelephoneCeremonyContractTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "an unreadable token is reported as a ceremony contract error" do
    error =
      assert_raises(IdentityTelephoneCeremony::Error) do
        IdentityTelephoneCeremonyContract.decode_unverified_payload("not-a-jwt")
      end

    assert_match(/token is invalid/, error.message)
  end
end
