# typed: false
# frozen_string_literal: true

require "test_helper"

# Characterization test (pre-enforcement baseline).
#
# BillingController is a staff-only (`AUTHENTICATION_MODE = :private`) read-only stub with NO
# object-level Action Policy check today, so any authenticated operator currently reaches it.
# These tests pin that current behavior so the Phase 3 object-level authorization rollout
# (ADR pundit-to-action-policy-migration.md) can prove which cases change: anonymous denial and
# cross-surface isolation MUST stay as they are; the "any operator succeeds" case is the one a
# role/permission check is expected to tighten.
class Sign::Org::BillingControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :clients

  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = operators(:one)
    @client = clients(:one)
  end

  test "index redirects when not signed in" do
    get sign_org_billing_index_url(ri: "jp"), headers: host_headers(@host)

    assert_response :redirect
    assert_match %r{\Ahttps://id\.umaxica\.org/sign/in/new\?ri=jp\z}, jump_rt_url_from_location(response.location)
  end

  test "index renders for any authenticated operator (no object authorization yet)" do
    get sign_org_billing_index_url(ri: "jp"), headers: as_staff_headers(@staff, host: @host)

    assert_response :success
    assert_equal "ok", response.body
  end

  test "client credentials do not authenticate as operator on the staff surface" do
    get sign_org_billing_index_url(ri: "jp"), headers: as_user_headers(@client, host: @host)

    assert_response :redirect
  end
end
