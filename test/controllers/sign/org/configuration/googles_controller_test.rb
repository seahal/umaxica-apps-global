# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Configuration::GooglesControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_identity_statuses, :operator_emails, :operator_email_statuses,
           :operator_chronicle_events, :operator_chronicle_levels, :operator_social_google_statuses

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
    create_google_identity!

    get sign_org_configuration_google_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_select "form[action=?]", sign_org_social_authentication_path(provider: "google_org", ri: "jp"), count: 1
    assert_select "form[action=?]", sign_org_configuration_google_path(ri: "jp"), count: 0
  end

  test "destroy disables google login and records activity" do
    identity = create_google_identity!

    assert_difference -> { OperatorChronicle.where(event_id: OperatorChronicleEvent::SOCIAL_UNLINKED).count }, 1 do
      delete sign_org_social_authentication_url(provider: "google_org", ri: "jp"), headers: @headers
    end

    assert_redirected_to sign_org_configuration_url(ri: "jp")
    assert_not OperatorSocialGoogle.exists?(identity.id)

    activity = OperatorChronicle.order(created_at: :desc).find_by!(event_id: OperatorChronicleEvent::SOCIAL_UNLINKED)

    assert_equal @staff.id, activity.subject_id
    assert_equal "Operator", activity.subject_type
    assert_equal "social", activity.context["auth_method"]
    assert_equal "google", activity.context["provider"]
  end

  test "should redirect show when not logged in" do
    get sign_org_configuration_google_url(ri: "jp")

    assert_response :redirect
    assert_equal "/", URI.parse(response.location).path
  end

  private

  def create_google_identity!
    OperatorSocialGoogle.create!(
      staff: @staff,
      uid: "google-org-#{SecureRandom.hex(4)}",
      provider: "google_org",
      token: "token",
      refresh_token: "refresh-token",
      token_expires_at: 1.week.from_now.to_i,
      status_id: OperatorSocialGoogleStatus::ACTIVE,
    )
  end
end
