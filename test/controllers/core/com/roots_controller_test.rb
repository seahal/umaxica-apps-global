# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Core::Com::RootsControllerTest < ActionDispatch::IntegrationTest
  BRAND = ENV.fetch("BRAND_NAME").upcase

  test "renders a thin landing page" do
    host! ENV.fetch("PUBLIC_CORE_CORPORATE_URL", ENV.fetch("PUBLIC_CORE_CORPORATE_URL", "core.com.localhost"))
    get core_com_root_url(ri: "jp")

    assert_response :success
    assert_select "title", "#{BRAND} (COM)"
    assert_equal "core/com/roots/index", inertia_component
    assert_nil inertia_props.fetch("title")
    assert_equal "Core Com", inertia_props.fetch("heading")
    assert_equal I18n.t("landing.thin_endpoint"), inertia_props.fetch("description")
  end

  test "creates preference cookies on root" do
    host! ENV.fetch("PUBLIC_CORE_CORPORATE_URL", ENV.fetch("PUBLIC_CORE_CORPORATE_URL", "core.com.localhost"))

    assert_difference("ComPreference.count", 1) do
      get core_com_root_url(ri: "jp")
    end

    assert_response :success
    assert_predicate cookies[PreferenceCookieName.access(surface: :com)], :present?
    assert_predicate cookies[PreferenceCookieName.refresh(surface: :com)], :present?
  end
end
