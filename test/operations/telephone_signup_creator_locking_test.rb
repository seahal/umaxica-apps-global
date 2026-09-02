# typed: false
# frozen_string_literal: true

require "test_helper"

# Two sessions registering the same number must not both pass the existence
# check, so the creator serialises per number -- and falls back to a plain
# transaction when there is no number digest to serialise on. A number whose
# existing row is still inside its cooldown is reported as rate limited and the
# transaction is rolled back, so no half-built registration is left behind.
class TelephoneSignupCreatorLockingTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a telephone with no digest to serialise on is refused inside a plain transaction" do
    telephone = ClientTelephone.new(
      raw_number: "", confirm_policy: "1", confirm_using_mfa: "1",
    )

    assert_no_difference -> { ClientTelephone.count } do
      assert_raises(ActiveRecord::RecordInvalid) do
        SignAppUpTelephoneSignupCreator.call(
          telephone: telephone, existing_telephone: nil, pending_public_id: nil,
        )
      end
    end
  end

  test "a number whose existing row is locked out is reported as rate limited and rolled back" do
    user = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP, visibility_id: ClientVisibility::USER)
    existing = ClientTelephone.create!(
      user: user, number: "+1234567650",
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
      confirm_policy: "1", confirm_using_mfa: "1",
    )
    existing.update!(locked_at: 10.minutes.from_now)
    candidate = ClientTelephone.new(
      raw_number: existing.number, confirm_policy: "1", confirm_using_mfa: "1",
    )
    candidate.validate

    result =
      assert_no_difference -> { ClientTelephone.count } do
        SignAppUpTelephoneSignupCreator.call(
          telephone: candidate, existing_telephone: existing, pending_public_id: nil,
        )
      end

    assert_equal :rate_limited, result.status
  end

  test "the corporate creator applies the same cooldown rule" do
    visitor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    existing = visitor.visitor_telephones.create!(
      raw_number: "+819012377650", confirm_policy: true, confirm_using_mfa: true,
      visitor_telephone_status_id: VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    existing.update!(locked_at: 10.minutes.from_now)
    candidate = VisitorTelephone.new(
      raw_number: existing.number, confirm_policy: true, confirm_using_mfa: true,
    )
    candidate.validate

    result =
      assert_no_difference -> { VisitorTelephone.count } do
        SignComUpTelephoneSignupCreator.call(
          telephone: candidate, existing_telephone: existing, pending_public_id: nil,
        )
      end

    assert_equal :rate_limited, result.status
  end
end
