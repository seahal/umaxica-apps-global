# typed: false
# frozen_string_literal: true

require "test_helper"

class SignedSessionReferenceTest < ActiveSupport::TestCase
  setup do
    UserStatus.find_or_create_by!(id: UserStatus::NOTHING)
    OperatorIdentityStatus.find_or_create_by!(id: OperatorIdentityStatus::NOTHING)
    UserTokenKind.find_or_create_by!(id: UserTokenKind::BROWSER_WEB)
    OperatorTokenKind.find_or_create_by!(id: OperatorTokenKind::BROWSER_WEB)

    @user = User.create!(public_id: "u_#{SecureRandom.hex(8)}", status_id: UserStatus::NOTHING)
    @staff = Operator.create!(staff_status: OperatorIdentityStatus.find(OperatorIdentityStatus::NOTHING))

    @user_token = UserToken.create!(user: @user, user_token_kind_id: UserTokenKind::BROWSER_WEB)
    @staff_token = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
  end

  test "signed refs round-trip and blank refs return nil" do
    assert_nil UserToken.find_from_signed_ref(nil)
    assert_nil UserToken.find_from_signed_ref("")

    assert_equal @user_token.id, UserToken.find_from_signed_ref(@user_token.signed_ref)&.id
    assert_equal @staff_token.id, OperatorToken.find_from_signed_ref(@staff_token.signed_ref)&.id
  end

  test "find_from_signed_ref returns nil for invalid signature" do
    assert_nil UserToken.find_from_signed_ref("invalid-signed-ref")
  end
end
