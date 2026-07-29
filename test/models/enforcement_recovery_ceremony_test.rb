# typed: false
# frozen_string_literal: true

require "test_helper"

class EnforcementRecoveryCeremonyTest < ActiveSupport::TestCase
  test "recovery ceremony authenticates only its unconsumed opaque token" do
    client = clients(:one)
    ceremony = ClientEnforcementRecoveryCeremony.issue!(subject: client, request: ActionDispatch::TestRequest.create)

    assert_equal ceremony, ClientEnforcementRecoveryCeremony.authenticate(
      public_id: ceremony.public_id, token: ceremony.plaintext_token,
    )

    ceremony.consume!

    assert_nil ClientEnforcementRecoveryCeremony.authenticate(public_id: ceremony.public_id, token: ceremony.plaintext_token)
  end
end
