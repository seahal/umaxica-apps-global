# frozen_string_literal: true

require "test_helper"

class PasskeyOptionsAnonymityInvariantTest < ActiveSupport::TestCase
  test "anonymous credential padding covers every surface passkey limit" do
    padding_count = PasskeySignInFlow::ANONYMIZED_ALLOW_CREDENTIALS_COUNT

    assert_operator padding_count, :>=, ClientPasskey::MAX_PASSKEYS_PER_USER
    assert_operator padding_count, :>=, VisitorPasskey::MAX_PASSKEYS_PER_VISITOR
    assert_operator padding_count, :>=, OperatorPasskey::MAX_PASSKEYS_PER_STAFF
  end
end
