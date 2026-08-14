# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Core::Org::RootsControllerTest < ActionDispatch::IntegrationTest
  BRAND = ENV.fetch("BRAND_NAME").upcase

  test "renders a thin landing page" do
    host! ENV.fetch("PUBLIC_CORE_STAFF_URL", "core.org.localhost")
    get core_org_root_url(ri: "jp")

    assert_response :success
    assert_select "title", "#{BRAND} (ORG)"
    assert_select "h1", text: "Core Org"
  end

  test "creates preference cookies on root" do
    host! ENV.fetch("PUBLIC_CORE_STAFF_URL", "core.org.localhost")

    assert_difference("OrgPreference.count", 1) do
      get core_org_root_url(ri: "jp")
    end

    assert_response :success
    assert_predicate cookies[PreferenceCookieName.access(surface: :org)], :present?
    assert_predicate cookies[PreferenceCookieName.refresh(surface: :org)], :present?
  end
end
