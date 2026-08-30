# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OrgOperatorLifecycleInvitationIssuerTest < ActiveSupport::TestCase
  fixtures :operators

  test "issues organization invitation from lifecycle request" do
    request = OperatorLifecycleRequest.create!(
      action: OperatorLifecycleRequest::ACTION_JOIN,
      status: OperatorLifecycleRequest::STATUS_APPROVED,
      target_email: "invitee@example.com",
      organization_id: 123,
      role_id: 7,
      requested_by_operator: operators(:one),
      approved_by_operator: operators(:two),
      approved_at: Time.current,
    )

    result = OrgOperatorLifecycleInvitationIssuer.call(request: request, actor: operators(:two))

    assert_predicate result, :success?
    assert_equal "invitee@example.com", result.invitation.email
    assert_equal 123, result.invitation.organization_id
    assert_equal 7, result.invitation.role_id
    assert_equal operators(:two).id, result.invitation.invited_by_id
  end
end
