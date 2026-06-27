# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Org::Settings::EmailsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_email_statuses, :operator_token_kinds
  include AuthHelpers

  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = operators(:one)
    @token = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    satisfy_staff_verification(@token)
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "settings_email")
    set_access_cookie(jwt_access_token_for(@staff, host: @host, session_public_id: @token.public_id))
    host! @host
  end

  test "sign settings emails index redirects to acme authority" do
    get sign_org_settings_emails_url(ri: "jp"), headers: session_headers

    assert_response :success
    assert_select "table"
  end

  test "sign settings email edit redirects without loading email" do
    get edit_sign_org_settings_email_url("missing", ri: "jp"), headers: session_headers

    assert_response :not_found
  end

  test "sign settings email update redirects without local preference mutation" do
    email = OperatorEmail.create!(
      address: "sign-org-email-update-redirect@example.com",
      staff: operators(:one),
      staff_email_status_id: OperatorEmailStatus::VERIFIED,
      promotional: true,
      notifiable: true,
    )

    assert_no_changes -> { email.reload.attributes.slice("promotional", "notifiable") } do
      patch sign_org_settings_email_url(email.public_id, ri: "jp"),
            params: { staff_email: { promotional: "0", notifiable: "0" } },
            headers: session_headers
    end

    assert_response :unprocessable_content
  end

  test "sign settings email destroy redirects without local account mutation" do
    email = OperatorEmail.create!(
      address: "sign-org-email-destroy-redirect@example.com",
      staff: operators(:one),
      staff_email_status_id: OperatorEmailStatus::VERIFIED,
    )

    assert_no_difference("OperatorEmail.count") do
      delete sign_org_settings_email_url(email.public_id, ri: "jp"), headers: session_headers
    end

    assert_redirected_to sign_org_settings_emails_url(ri: "jp")
    assert_not_predicate email.reload, :destroyed?
  end

  test "sign email registration route remains on sign ceremony surface" do
    get new_sign_org_settings_emails_registration_url(ri: "jp"), headers: session_headers

    assert_equal "sign/org/settings/emails/registrations", @request.path_parameters[:controller]
    assert_equal "new", @request.path_parameters[:action]
  end

  private

  def session_headers
    as_staff_headers(@staff, host: @host, session_public_id: @token.public_id)
  end
end
