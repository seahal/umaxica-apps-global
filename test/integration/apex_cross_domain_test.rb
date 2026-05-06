# typed: false
# frozen_string_literal: true

require "test_helper"

# This test verifies cross-domain links between apex and other domains
class ApexCrossDomainLinksTest < ActionDispatch::IntegrationTest
  test "apex layouts link to other domains correctly" do
    host! ENV.fetch("APEX_SERVICE_URL", "www.app.localhost")

    get apex_app_root_url(ri: "jp")

    assert_response :success

    # Apex layouts should have links to other domains
    assert_select "a[href^='http']", minimum: 1
  end

  test "cross domain url helpers are accessible from apex" do
    # Apex helpers should be accessible
    assert_respond_to self, :apex_app_root_url
    assert_respond_to self, :apex_com_root_url
    assert_respond_to self, :apex_org_root_url

    assert_respond_to self, :sign_app_root_url
  end
end
