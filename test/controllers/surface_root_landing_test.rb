# typed: false
# frozen_string_literal: true

require "test_helper"

# Gateway-root canonicalization for the base and auth surfaces. A root request
# without a region is first normalized to the default region, and the regional
# request is then canonicalized: base surfaces move to the regional host,
# auth surfaces move to their own sign-in entry point.
class SurfaceRootLandingTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "base app root without a region is normalized to the default region" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host

    get base_app_root_url(host: host), headers: { "Host" => host }

    assert_response :redirect
    assert_match(/\Ahttp:\/\/#{Regexp.escape(host)}\/\?ri=/, response.location)
  end

  test "base app root with a region is canonicalized to the regional host" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host

    get base_app_root_url(ri: "jp", host: host), headers: { "Host" => host }

    assert_response :moved_permanently
    assert_equal RegionalRootUrlRegistry.url_for(surface: :app, region: "jp"), response.location
  end

  test "base com root with a region is canonicalized to the regional host" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host

    get base_com_root_url(ri: "jp", host: host), headers: { "Host" => host }

    assert_response :moved_permanently
    assert_equal RegionalRootUrlRegistry.url_for(surface: :com, region: "jp"), response.location
  end

  test "base org root with a region is canonicalized to the regional host" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! host

    get base_org_root_url(ri: "jp", host: host), headers: { "Host" => host }

    assert_response :moved_permanently
    assert_equal RegionalRootUrlRegistry.url_for(surface: :org, region: "jp"), response.location
  end

  test "base app root leaves an unrecognized region to region normalization rather than redirecting" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host

    get base_app_root_url(ri: "zz", host: host), headers: { "Host" => host }

    assert_response :redirect
    assert_not_equal RegionalRootUrlRegistry.url_for(surface: :app, region: "jp"), response.location
  end

  test "auth app root with a region is canonicalized to the sign-in entry point" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host

    get auth_app_root_url(ri: "jp", host: host), headers: { "Host" => host }

    assert_response :moved_permanently
    assert_redirected_to auth_app_sign_in_path(ri: "jp")
  end

  test "auth com root with a region is canonicalized to the sign-in entry point" do
    host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    host! host

    get auth_com_root_url(ri: "jp", host: host), headers: { "Host" => host }

    assert_response :moved_permanently
    assert_redirected_to auth_com_sign_in_path(ri: "jp")
  end

  test "auth org root with a region is canonicalized to the sign-in entry point" do
    host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    host! host

    get auth_org_root_url(ri: "jp", host: host), headers: { "Host" => host }

    assert_response :moved_permanently
    assert_redirected_to auth_org_sign_in_path(ri: "jp")
  end
end
