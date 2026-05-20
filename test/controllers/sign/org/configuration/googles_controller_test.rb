# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Sign::Org::Configuration::GooglesControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_identity_statuses, :operator_emails, :operator_email_statuses,
           :operator_chronicle_events, :operator_chronicle_levels

  setup do
    @host = ENV.fetch("SIGN_STAFF_URL", "id.org.localhost")
    host! @host
    @staff = operators(:one)
    @headers = { "Host" => @host, "X-TEST-CURRENT-STAFF" => @staff.id }.freeze
  end

  test "should get show when logged in" do
    get sign_org_configuration_google_url(ri: "jp"), headers: @headers

    assert_response :success
  end

  test "create redirects to google social session" do
    post sign_org_configuration_google_url(ri: "jp"), headers: @headers

    assert_match(%r{/auth/google_org\?state=}, response.location)
    assert_predicate session[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY], :present?
    assert_equal "google_org", session[SocialCallbackGuard::SOCIAL_STATE_PROVIDER_SESSION_KEY]
  end

  test "show offers connect when google login is not linked" do
    get sign_org_configuration_google_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_select "form[action=?]", sign_org_configuration_google_path(ri: "jp"), count: 1
    assert_select "form[action=?]", sign_org_social_authentication_path(provider: "google_org", ri: "jp"), count: 0
  end

  test "show offers disconnect when google login is linked" do
    create_staff_email!(undeletable: true)

    get sign_org_configuration_google_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_select "form[action=?]", sign_org_social_authentication_path(provider: "google_org", ri: "jp"), count: 1
    assert_select "form[action=?]", sign_org_configuration_google_path(ri: "jp"), count: 0
  end

  test "destroy disables google login and records activity" do
    staff_email = create_staff_email!(undeletable: true)

    assert_difference -> { OperatorChronicle.where(event_id: OperatorChronicleEvent::SOCIAL_UNLINKED).count }, 1 do
      delete sign_org_social_authentication_url(provider: "google_org", ri: "jp"), headers: @headers
    end

    assert_redirected_to sign_org_configuration_url(ri: "jp")
    assert_not_predicate staff_email.reload, :undeletable?

    activity = OperatorChronicle.order(created_at: :desc).find_by!(event_id: OperatorChronicleEvent::SOCIAL_UNLINKED)

    assert_equal @staff.id, activity.subject_id
    assert_equal "Operator", activity.subject_type
    assert_equal "social", activity.context["auth_method"]
    assert_equal "google", activity.context["provider"]
  end

  test "should redirect show when not logged in" do
    get sign_org_configuration_google_url(ri: "jp")
    rt = Base64.urlsafe_encode64(sign_org_configuration_google_url(ri: "jp"))

    assert_redirected_to new_sign_org_in_url(rt: rt, host: @host)
  end

  private

  def create_staff_email!(undeletable:)
    OperatorEmail.create!(
      staff: @staff,
      address: "google-org-#{SecureRandom.hex(4)}@example.test",
      staff_email_status_id: OperatorEmailStatus::VERIFIED,
      otp_counter: "0",
      otp_private_key: "otp-private-key",
      undeletable: undeletable,
    )
  end
end
