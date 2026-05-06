# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::UpsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
  end

  test "should get new" do
    get new_sign_org_up_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :success
  end

  test "renders recruit contact and home links" do
    get new_sign_org_up_url(ri: "jp"), headers: { "Host" => @host }

    apex_host = ENV["APEX_STAFF_URL"].presence || "www.org.localhost"
    # Match the URL while allowing any order of query parameters
    assert_select "div a[href^=?]", "http://#{apex_host}/",
                  text: I18n.t("sign.org.ups.new.recruit_link_text")

    # Verify that the URL contains all required parameters
    link = css_select("div a").find { |a| a.text == I18n.t("sign.org.ups.new.recruit_link_text") }

    assert_not_nil link,
                   "Could not find link with text: #{I18n.t("sign.org.ups.new.recruit_link_text").inspect}"
    href = link["href"]

    assert_match(/ri=jp/, href)
  end
end
