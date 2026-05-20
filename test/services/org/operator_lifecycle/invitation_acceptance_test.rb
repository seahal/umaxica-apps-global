# typed: false
# frozen_string_literal: true

require "test_helper"

class Org::OperatorLifecycle::InvitationAcceptanceTest < ActiveSupport::TestCase
  fixtures :operators, :operator_identity_statuses, :operator_email_statuses, :operator_visibilities

  setup do
    @invitation = OrganizationInvitation.create!(
      organization_id: 123,
      email: "invitee@example.com",
      invited_by: operators(:one),
      role_id: 7,
    )
  end

  test "accepts invitation by creating active operator and protected verified email" do
    assert_difference -> { Operator.count }, 1 do
      assert_difference -> { OperatorEmail.count }, 1 do
        assert_difference -> { OperatorAccount.count }, 1 do
          @result = Org::OperatorLifecycle::InvitationAcceptance.call(invitation_code: @invitation.code)
        end
      end
    end

    assert_predicate @result, :success?
    assert_predicate @invitation.reload, :consumed?
    assert_equal OperatorIdentityStatus::ACTIVE, @result.operator.status_id
    assert_equal OperatorVisibility::STAFF, @result.operator.visibility_id
    assert_equal "invitee@example.com", @result.email.address
    assert_equal OperatorEmailStatus::VERIFIED, @result.email.staff_email_status_id
    assert_predicate @result.email, :undeletable?
    assert_predicate @result.operator.rp_account, :present?
  end

  test "rejects consumed invitation without creating operator" do
    @invitation.update!(consumed_at: Time.current)

    assert_no_difference -> { Operator.count } do
      result = Org::OperatorLifecycle::InvitationAcceptance.call(invitation_code: @invitation.code)

      assert_not result.success?
    end
  end

  test "keeps invitation active when operator email cannot be created" do
    existing = Operator.create!(
      status_id: OperatorIdentityStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    existing.operator_emails.create!(
      raw_address: @invitation.email,
      confirm_policy: true,
      staff_email_status_id: OperatorEmailStatus::VERIFIED,
    )

    result = Org::OperatorLifecycle::InvitationAcceptance.call(invitation_code: @invitation.code)

    assert_not result.success?
    assert_not_predicate @invitation.reload, :consumed?
  end
end
