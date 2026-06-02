# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::App::RootsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    host! ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    get acme_app_root_url(ri: "jp")

    assert_response :success
    assert_select "title",
                  "#{ENV.fetch("BRAND_NAME", "UMAXICA").upcase} (app) | #{I18n.t("acme.app.preferences.footer.home")}"
    assert_select "main a[href*='/preference']", false
  end

  # Regression: the public landing page must not perform a per-request
  # preference create/rotate write (DBSC performance plan).
  test "does not create preference records on root" do
    host! ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")

    assert_no_difference("AppPreference.count") do
      get acme_app_root_url(ri: "jp")
    end

    assert_response :success
  end
end
