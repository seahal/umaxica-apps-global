# typed: false
# frozen_string_literal: true

require "test_helper"

class Core::Com::RootsControllerTest < ActionDispatch::IntegrationTest
  test "renders a thin landing page" do
    host! ENV.fetch("PUBLIC_CORE_CORPORATE_URL", ENV.fetch("PUBLIC_CORE_CORPORATE_URL", "core.com.localhost"))
    get core_com_root_url(ri: "jp")

    assert_response :success
    assert_select "title", "Core Com"
    assert_select "h1", text: "Core Com"
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
