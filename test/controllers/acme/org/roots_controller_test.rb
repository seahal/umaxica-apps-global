# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::Org::RootsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    host! ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    get acme_org_root_url(ri: "jp")

    assert_response :success
    assert_select "title",
                  "#{ENV.fetch("BRAND_NAME", "UMAXICA").upcase} (org) | #{I18n.t("acme.org.preferences.footer.home")}"
  end
end
