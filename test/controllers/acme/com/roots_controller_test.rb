# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::Com::RootsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    host! ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    get acme_com_root_url(ri: "jp")

    assert_response :success
    assert_select "title",
                  "#{ENV.fetch("BRAND_NAME", "UMAXICA").upcase} (com) | #{I18n.t("acme.com.preferences.footer.home")}"
  end

  # Regression: the public landing page must not perform a per-request
  # preference create/rotate write (DBSC performance plan).
  test "does not create preference records on root" do
    host! ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")

    assert_no_difference("ComPreference.count") do
      get acme_com_root_url(ri: "jp")
    end

    assert_response :success
  end
end
