# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Up::EmailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("ID_ORGANIZATION_URL", "id.org.localhost")
    @host = ENV.fetch("ID_ORGANIZATION_URL", "id.org.localhost")
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
    [0, 1, 2, 3].each { |id| OrganizationStatus.find_or_create_by!(id: id) }
    @staff = Staff.create!(status_id: StaffStatus::ACTIVE)
    @organization = Organization.create!(name: "Test Org")
    @invitation = OrganizationInvitation.create!(
      organization_id: @organization.id,
      email: "invitee@example.com",
      invited_by: @staff,
    )
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "get new" do
    get new_sign_org_up_email_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :success
  end

  test "create without invitation is rejected" do
    post sign_org_up_emails_url(ri: "jp"),
         params: {
           staff_email: { raw_address: "new-org@example.com", confirm_policy: "1" },
           "cf-turnstile-response": "test",
         },
         headers: { "Host" => @host }

    assert_response :unprocessable_content
  end

  test "create with invalid invitation is rejected" do
    post sign_org_up_emails_url(ri: "jp"),
         params: {
           invitation_code: "invalid-code",
           staff_email: { raw_address: "new-org@example.com", confirm_policy: "1" },
           "cf-turnstile-response": "test",
         },
         headers: { "Host" => @host }

    assert_response :unprocessable_content
  end

  test "create with valid invitation redirects to invitation email step" do
    post sign_org_up_emails_url(ri: "jp"),
         params: {
           invitation_code: @invitation.code,
           staff_email: { raw_address: "new-org@example.com", confirm_policy: "1" },
           "cf-turnstile-response": "test",
         },
         headers: { "Host" => @host }

    assert_redirected_to new_sign_org_up_email_url(invitation_code: @invitation.code, ri: "jp")
  end
end
