# typed: false
# frozen_string_literal: true

require "test_helper"

class MultiFactorStatusTrackableTest < ActiveSupport::TestCase
  test "new actors default status to unconfigured" do
    assert_equal UserMultiFactorStatus::UNCONFIGURED, User.new.multi_factor_status_id
    assert_equal OperatorMultiFactorStatus::UNCONFIGURED, Operator.new.multi_factor_status_id
    assert_equal VisitorMultiFactorStatus::UNCONFIGURED, Visitor.new.multi_factor_status_id
  end

  test "user refreshes to unconfigured without app step up methods" do
    user = User.create!

    assert_equal UserMultiFactorStatus::UNCONFIGURED, user.reload.multi_factor_status_id
    assert_predicate user, :multi_factor_status_unconfigured?
  end

  test "raises when placeholder status is used for runtime checks" do
    user = User.create!
    user.update_column(:multi_factor_status_id, UserMultiFactorStatus::NOTHING)

    assert_raises(MultiFactorStatusTrackable::InvalidMultiFactorStatus) do
      user.reload.multi_factor_status_unconfigured?
    end
  end

  test "assigns unconfigured before validation when placeholder is present" do
    user = User.create!
    user.update_column(:multi_factor_status_id, UserMultiFactorStatus::NOTHING)

    user = User.find(user.id)

    assert_predicate user, :valid?

    assert_equal UserMultiFactorStatus::UNCONFIGURED, user.multi_factor_status_id
  end

  test "user refreshes to active with verified email" do
    user = User.create!

    UserEmail.create!(
      user: user,
      address: "mfs-user-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: UserEmailStatus::VERIFIED,
    )

    assert_equal UserMultiFactorStatus::ACTIVE, user.reload.multi_factor_status_id
    assert_predicate user, :multi_factor_status_active?
  end

  test "user refreshes from unconfigured to active after verified email registration" do
    user = User.create!

    assert_equal UserMultiFactorStatus::UNCONFIGURED, user.reload.multi_factor_status_id

    UserEmail.create!(
      user: user,
      address: "mfs-unconfigured-user-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: UserEmailStatus::VERIFIED,
    )

    assert_equal UserMultiFactorStatus::ACTIVE, user.reload.multi_factor_status_id
  end

  test "user refresh ignores stale loaded email association" do
    user = User.create!
    user.user_emails.load

    UserEmail.create!(
      user: user,
      address: "mfs-stale-user-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: UserEmailStatus::VERIFIED,
    )

    assert_equal UserMultiFactorStatus::ACTIVE, user.reload.multi_factor_status_id
  end

  test "user refreshes back to unconfigured when last method is no longer verified" do
    user = User.create!
    email = UserEmail.create!(
      user: user,
      address: "mfs-demote-user-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: UserEmailStatus::VERIFIED,
    )

    email.update!(user_email_status_id: UserEmailStatus::UNVERIFIED)

    assert_equal UserMultiFactorStatus::UNCONFIGURED, user.reload.multi_factor_status_id
  end

  test "operator refreshes to active with passkey" do
    operator = Operator.create!

    OperatorPasskey.create!(
      staff: operator,
      name: "Security key",
      public_key: "public-key",
      webauthn_id: SecureRandom.hex(16),
      status_id: OperatorPasskeyStatus::ACTIVE,
    )

    assert_equal OperatorMultiFactorStatus::ACTIVE, operator.reload.multi_factor_status_id
  end

  test "visitor refreshes to active with verified email" do
    visitor = Visitor.create!

    VisitorEmail.create!(
      visitor: visitor,
      address: "mfs-visitor-#{SecureRandom.hex(4)}@example.com",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )

    assert_equal VisitorMultiFactorStatus::ACTIVE, visitor.reload.multi_factor_status_id
  end
end
