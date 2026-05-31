# typed: false
# frozen_string_literal: true

require "test_helper"

class Core::Com::RootsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    host! ENV.fetch("CORE_CORPORATE_URL", "www.jp.umaxica.com")
    get core_com_root_url(ri: "jp")

    assert_response :success
  end

  # Regression: the public landing page must not perform a per-request
  # preference create/rotate write (DBSC performance plan).
  test "does not create preference records on root" do
    host! ENV.fetch("CORE_CORPORATE_URL", "www.jp.umaxica.com")

    assert_no_difference("ComPreference.count") do
      get core_com_root_url(ri: "jp")
    end

    assert_response :success
  end
end
