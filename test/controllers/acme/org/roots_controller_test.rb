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

  test "creates preference cookies on root" do
    host! ENV.fetch("ACME_STAFF_URL", "www.org.localhost")

    assert_difference("OrgPreference.count", 1) do
      get acme_org_root_url(ri: "jp")
    end

    assert_response :success
    assert_predicate cookies[Preference::CookieName.access(surface: :org)], :present?
    assert_predicate cookies[Preference::CookieName.refresh(surface: :org)], :present?
  end

  test "creates preference cookies on root when optional URL preferences are present" do
    host! ENV.fetch("ACME_STAFF_URL", "www.org.localhost")

    assert_difference("OrgPreference.count", 1) do
      get acme_org_root_url(ct: "dr", lx: "en", ri: "us", tz: "asia/tokyo")
    end

    assert_response :success
    assert_predicate cookies[Preference::CookieName.access(surface: :org)], :present?
    assert_predicate cookies[Preference::CookieName.refresh(surface: :org)], :present?
  end
end
