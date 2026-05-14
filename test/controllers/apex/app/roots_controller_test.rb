# typed: false
# frozen_string_literal: true

require "test_helper"

class Apex::App::RootsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    host! ENV.fetch("APEX_SERVICE_URL", "www.app.localhost")
    get apex_app_root_url(ri: "jp")

    assert_response :success
    assert_select "title",
                  "#{ENV.fetch("BRAND_NAME", "UMAXICA").upcase} (app) | #{I18n.t("apex.app.preferences.footer.home")}"
  end
end
