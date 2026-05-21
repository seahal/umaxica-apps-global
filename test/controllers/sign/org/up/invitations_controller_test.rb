# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Up::InvitationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_identity_statuses, :operator_email_statuses, :operator_visibilities

  setup do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
    @invitation = OrganizationInvitation.create!(
      organization_id: 123,
      email: "invitee-controller@example.com",
      invited_by: operators(:one),
      role_id: 7,
    )
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "new renders invitation acceptance form" do
    get new_sign_org_up_invitation_url(invitation_code: @invitation.code, ri: "jp")

    assert_response :success
    assert_select "input[name=?]", "invitation_code"
    assert_select "input[name='cf-turnstile-response'][type='hidden']", count: 1
    assert_includes response.body, "turnstile.render"
  end

  test "create accepts invitation and redirects to sign in" do
    assert_difference -> { Operator.count }, 1 do
      post sign_org_up_invitations_url(ri: "jp"),
           params: { invitation_code: @invitation.code, "cf-turnstile-response": "test" }
    end

    assert_redirected_to new_sign_org_in_path(ri: "jp")
    assert_predicate @invitation.reload, :consumed?
    assert_match(/operator ID/i, flash[:notice])
  end

  test "create renders new for invalid invitation" do
    assert_no_difference -> { Operator.count } do
      post sign_org_up_invitations_url(ri: "jp"),
           params: { invitation_code: "missing", "cf-turnstile-response": "test" }
    end

    assert_response :unprocessable_content
  end

  test "create rejects failed turnstile before accepting invitation" do
    CloudflareTurnstile.test_validation_response = { "success" => false }

    assert_no_difference -> { Operator.count } do
      post sign_org_up_invitations_url(ri: "jp"),
           params: { invitation_code: @invitation.code, "cf-turnstile-response": "test" }
    end

    assert_response :unprocessable_content
    assert_not_predicate @invitation.reload, :consumed?
  end
end
