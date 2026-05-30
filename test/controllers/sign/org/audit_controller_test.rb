# typed: false
# frozen_string_literal: true

require "test_helper"

# Characterization test (pre-enforcement baseline).
#
# AuditController is a staff-only (`AUTHENTICATION_MODE = :private`) read-only stub. It performs
# NO object-level Action Policy check today (`authorize!` is not called), so any authenticated
# operator currently reaches it. These tests pin that current behavior so the later object-level
# authorization rollout (ADR pundit-to-action-policy-migration.md, Phase 3) can prove exactly
# which cases change: anonymous denial and cross-surface isolation MUST stay as they are; the
# "any operator succeeds" case is the one a role/permission check is expected to tighten.
class Sign::Org::AuditControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :clients

  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = operators(:one)
    @client = clients(:one)
  end

  test "index redirects when not signed in" do
    get sign_org_audit_index_url(ri: "jp"), headers: host_headers(@host)

    assert_response :redirect
    assert_match %r{\Ahttps://id\.umaxica\.org/sign/in/new\?ri=jp\z}, jump_rt_url_from_location(response.location)
  end

  test "index renders for any authenticated operator (no object authorization yet)" do
    get sign_org_audit_index_url(ri: "jp"), headers: as_staff_headers(@staff, host: @host)

    assert_response :success
    assert_equal "ok", response.body
  end

  test "client credentials do not authenticate as operator on the staff surface" do
    get sign_org_audit_index_url(ri: "jp"), headers: as_user_headers(@client, host: @host)

    assert_response :redirect
  end
end
