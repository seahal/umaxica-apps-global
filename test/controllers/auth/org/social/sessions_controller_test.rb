# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Org::Social::SessionsControllerTest < ActionDispatch::IntegrationTest
  TENANT_ID = "11111111-2222-3333-4444-555555555555"

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
    host! @host
    Rails.configuration.x.rate_limit.fetch(:store).clear
    OrganizationEntraConnectionState.ensure_defaults!

    @connection = OrganizationEntraConnection.create!(
      organization_id: 1,
      entra_tenant_id: TENANT_ID,
      entra_client_id: "org-social-sessions-controller-test-client",
      entra_credential_key: "org-social-sessions-controller-test-secret",
      status_id: OrganizationEntraConnectionState::ACTIVE,
    )
  end

  teardown do
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  test "staff sign-in page offers the Entra ceremony entry point" do
    get "/sign/in", params: { ri: "jp" }

    assert_response :success
    assert_select "form[action=?][method=?]", auth_org_social_entra_session_path(ri: "jp"), "post"
  end

  test "POST without a connection renders the cushion page rather than starting a ceremony" do
    post auth_org_social_entra_session_path(ri: "jp")

    assert_response :success
    assert_select "input[name=?]", "connection_public_id"
    assert_select "form[action=?]", "/social/entra", count: 0
  end

  test "POST with an active connection hands the ceremony off with a 307" do
    post auth_org_social_entra_session_path(ri: "jp"),
         params: { connection_public_id: @connection.public_id }

    assert_response :temporary_redirect
    assert_equal "http://#{@host}/social/entra", response.location
  end

  test "POST with an unknown connection renders the same generic error as an inactive one" do
    post auth_org_social_entra_session_path(ri: "jp"),
         params: { connection_public_id: "does-not-exist" }

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.org.authentication.entra.new.connection_not_found")
    assert_select "form[action=?]", "/social/entra", count: 0

    @connection.update!(status_id: OrganizationEntraConnectionState::REVOKED)

    post auth_org_social_entra_session_path(ri: "jp"),
         params: { connection_public_id: @connection.public_id }

    # Status, message, and absence of the ceremony form must match the unknown
    # case exactly, or this endpoint would disclose which organizations have an
    # Entra connection configured.
    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.org.authentication.entra.new.connection_not_found")
    assert_select "form[action=?]", "/social/entra", count: 0
  end

  test "GET new still honours the ?connection= link contract" do
    get new_auth_org_social_entra_session_path(connection: @connection.public_id, ri: "jp")

    assert_response :success
    assert_select "form[action=?]", "/social/entra"
    assert_select "input[name=?][value=?]", "connection_public_id", @connection.public_id
  end

  test "GET new renders a form and cannot start the ceremony on its own" do
    # A GET carries no CSRF token, so a GET that started a ceremony would be
    # login CSRF (CVE-2015-9284) - the reason the app surface has no GET entry
    # at all. This GET is a landing page only: it renders the button and sends
    # nothing to Microsoft until a person presses it. Only #create hands off.
    get new_auth_org_social_entra_session_path(connection: @connection.public_id, ri: "jp")

    assert_response :success
    assert_no_match(
      /\.submit\(\)/, response.body,
      "the landing page must not submit itself: a person has to press the button",
    )
  end

  test "the ceremony start endpoint is not reachable by GET" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{@host}/social/entra/session", method: :get)
    end
  end

  test "POST fails closed and starts no ceremony when the Entra provider is unavailable" do
    disabled = Object.new
    disabled.define_singleton_method(:start_decision) { |**|
      ExternalAuthentication::AvailabilityDecision.new(
        state: :disabled, source: "test", configuration_version: nil, reason_code: "test_disabled",
        incident_id: nil, observed_at: Time.current,
      )
    }

    ExternalAuthentication::ProviderAvailabilityFactory.stub(:current, disabled) do
      post auth_org_social_entra_session_path(ri: "jp"),
           params: { connection_public_id: @connection.public_id }
    end

    assert_response :service_unavailable
    assert_includes response.body, I18n.t("sign.org.authentication.entra.errors.provider_unavailable")
    assert_select "form[action=?]", "/social/entra", count: 0
  end

  test "POST is rate limited per client address" do
    21.times do
      post auth_org_social_entra_session_path(ri: "jp"),
           params: { connection_public_id: "does-not-exist" }
    end

    assert_response :too_many_requests
  end

  test "route recognizes the ceremony start endpoint" do
    route = Rails.application.routes.recognize_path("http://#{@host}/social/entra/session", method: :post)

    assert_equal "auth/org/social/sessions", route[:controller]
    assert_equal "create", route[:action]
    assert_equal "entra", route[:provider]
  end
end
