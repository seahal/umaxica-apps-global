# typed: false
# frozen_string_literal: true

require "test_helper"

class Core::Org::RootsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    host! ENV.fetch("CORE_STAFF_URL", "www.jp.umaxica.org")
    get core_org_root_url(ri: "jp")

    assert_response :success
  end

  # Regression: the public landing page must not perform a per-request
  # preference create/rotate write (DBSC performance plan).
  test "does not create preference records on root" do
    host! ENV.fetch("CORE_STAFF_URL", "www.jp.umaxica.org")

    assert_no_difference("OrgPreference.count") do
      get core_org_root_url(ri: "jp")
    end

    assert_response :success
  end
end
