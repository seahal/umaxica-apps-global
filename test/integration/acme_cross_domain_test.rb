# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

# This test verifies cross-domain links between acme and other domains
class AcmeCrossDomainLinksTest < ActionDispatch::IntegrationTest
  test "acme layouts link to other domains correctly" do
    host! ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost")

    get acme_app_root_url(ri: "jp")

    assert_response :success

    # Acme layouts should have links to other domains
    assert_select "a[href^='http']", minimum: 1
  end

  test "cross domain url helpers are accessible from acme" do
    # Acme helpers should be accessible
    assert_respond_to self, :acme_app_root_url
    assert_respond_to self, :acme_com_root_url
    assert_respond_to self, :acme_org_root_url

    assert_respond_to self, :sign_app_root_url
  end
end
