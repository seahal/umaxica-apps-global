# typed: false
# frozen_string_literal: true

require "test_helper"

class Core::Org::RootsControllerTest < ActionDispatch::IntegrationTest
  test "renders a thin landing page" do
    host! ENV.fetch("CORE_STAFF_URL", "jpx.umaxica.org")
    get core_org_root_url(ri: "jp")

    assert_response :success
    assert_select "title", "Core Org"
    assert_select "h1", text: "Core Org"
  end

  test "creates preference cookies on root" do
    host! ENV.fetch("CORE_STAFF_URL", "jpx.umaxica.org")

    assert_difference("OrgPreference.count", 1) do
      get core_org_root_url(ri: "jp")
    end

    assert_response :success
    assert_predicate cookies[PreferenceCookieName.access(surface: :org)], :present?
    assert_predicate cookies[PreferenceCookieName.refresh(surface: :org)], :present?
  end
end
