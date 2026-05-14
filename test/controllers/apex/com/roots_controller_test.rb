# typed: false
# frozen_string_literal: true

require "test_helper"

class Apex::Com::RootsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    host! ENV.fetch("APEX_CORPORATE_URL", "www.com.localhost")
    get apex_com_root_url(ri: "jp")

    assert_response :success
    assert_select "title",
                  "#{ENV.fetch("BRAND_NAME", "UMAXICA").upcase} (com) | #{I18n.t("apex.com.preferences.footer.home")}"
  end
end
