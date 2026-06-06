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

  test "creates preference cookies on root" do
    host! ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")

    assert_difference("ComPreference.count", 1) do
      get acme_com_root_url(ri: "jp")
    end

    assert_response :success
    assert_predicate cookies[PreferenceCookieName.access(surface: :com)], :present?
    assert_predicate cookies[PreferenceCookieName.refresh(surface: :com)], :present?
  end

  test "creates preference cookies on root when optional URL preferences are present" do
    host! ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")

    assert_difference("ComPreference.count", 1) do
      get acme_com_root_url(ct: "dr", lx: "en", ri: "us", tz: "asia/tokyo")
    end

    assert_response :success
    assert_predicate cookies[PreferenceCookieName.access(surface: :com)], :present?
    assert_predicate cookies[PreferenceCookieName.refresh(surface: :com)], :present?
  end
end
