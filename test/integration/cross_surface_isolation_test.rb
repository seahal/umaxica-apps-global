# typed: false
# frozen_string_literal: true

require "test_helper"

# Characterization test (pre-enforcement baseline) -- cross-surface actor isolation.
#
# The three surfaces (app/client, com/visitor, org/operator) are independent authentication
# boundaries. Credentials minted for one surface must not authenticate an actor on another
# surface's host. The per-surface dashboard (`AUTHENTICATION_MODE = :private`, trivial `show`) is
# used as a representative protected endpoint; each surface's own DashboardsControllerTest already
# covers anonymous-redirect and own-surface success, so this test pins the missing cross-surface
# denial matrix.
#
# This invariant is enforced at authentication time (the foreign actor never resolves), which is
# distinct from -- and must survive -- the upcoming object-level Action Policy enforcement rollout
# (ADR pundit-to-action-policy-migration.md, Phase 3). If a future change accidentally let one
# surface's session authorize another surface, these assertions fail.
class CrossSurfaceIsolationTest < ActionDispatch::IntegrationTest
  fixtures :operators, :clients

  APP_HOST = ENV.fetch("ID_SERVICE_URL")
  COM_HOST = ENV.fetch("SIGN_CORPORATE_URL")
  ORG_HOST = ENV.fetch("ID_STAFF_URL")

  setup do
    @client = clients(:one)
    @operator = operators(:one)
    @visitor = create_verified_visitor_with_email(email_address: "isolation-#{SecureRandom.hex(4)}@example.com")
    # The com surface gates on a verified telephone (enforce_required_telephone_registration!),
    # so the visitor positive control needs one to reach the dashboard.
    @visitor.visitor_telephones.create!(
      number: "+1000000#{SecureRandom.random_number(10_000).to_s.rjust(4, "0")}",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
  end

  # --- positive controls: each surface accepts its own actor ---

  test "client is authenticated on the app dashboard" do
    get sign_app_dashboard_url(ri: "jp"), headers: as_user_headers(@client, host: APP_HOST)

    assert_same_surface_dashboard_redirect(APP_HOST)
  end

  test "visitor is authenticated on the com dashboard" do
    get sign_com_dashboard_url(ri: "jp"), headers: as_visitor_headers(@visitor, host: COM_HOST)

    assert_same_surface_dashboard_redirect(COM_HOST)
  end

  test "operator is authenticated on the org dashboard" do
    get sign_org_dashboard_url(ri: "jp"), headers: as_staff_headers(@operator, host: ORG_HOST)

    assert_same_surface_dashboard_redirect(ORG_HOST)
  end

  # --- isolation matrix: foreign-surface credentials are rejected (redirect to sign-in) ---

  test "operator credentials are rejected on the app surface" do
    get sign_app_dashboard_url(ri: "jp"), headers: as_staff_headers(@operator, host: APP_HOST)

    assert_response :redirect
  end

  test "visitor credentials are rejected on the app surface" do
    get sign_app_dashboard_url(ri: "jp"), headers: as_visitor_headers(@visitor, host: APP_HOST)

    assert_response :redirect
  end

  test "client credentials are rejected on the com surface" do
    get sign_com_dashboard_url(ri: "jp"), headers: as_user_headers(@client, host: COM_HOST)

    assert_response :redirect
  end

  test "operator credentials are rejected on the com surface" do
    get sign_com_dashboard_url(ri: "jp"), headers: as_staff_headers(@operator, host: COM_HOST)

    assert_response :redirect
  end

  test "client credentials are rejected on the org surface" do
    get sign_org_dashboard_url(ri: "jp"), headers: as_user_headers(@client, host: ORG_HOST)

    assert_response :redirect
  end

  test "visitor credentials are rejected on the org surface" do
    get sign_org_dashboard_url(ri: "jp"), headers: as_visitor_headers(@visitor, host: ORG_HOST)

    assert_response :redirect
  end

  private

  def assert_same_surface_dashboard_redirect(_sign_host)
    assert_response :success
  end
end
