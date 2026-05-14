# typed: false
# frozen_string_literal: true

require "test_helper"

class Apex::Org::RootsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    host! ENV.fetch("APEX_STAFF_URL", "www.org.localhost")
    get apex_org_root_url(ri: "jp")

    assert_response :success
    assert_select "title",
                  "#{ENV.fetch("BRAND_NAME", "UMAXICA").upcase} (org) | #{I18n.t("apex.org.preferences.footer.home")}"
  end
end
