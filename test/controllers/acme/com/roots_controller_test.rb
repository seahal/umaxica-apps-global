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
end
