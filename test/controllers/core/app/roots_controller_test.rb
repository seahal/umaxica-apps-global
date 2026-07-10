# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Core::App::RootsControllerTest < ActionDispatch::IntegrationTest
  test "renders a thin landing page" do
    host! ENV.fetch("PUBLIC_CORE_SERVICE_URL", ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost"))
    get core_app_root_url(ri: "jp")

    assert_response :success
    assert_select "title", "Core App"
    assert_select "h1", text: "Core App"
  end

  test "creates preference cookies on root" do
    host! ENV.fetch("PUBLIC_CORE_SERVICE_URL", ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost"))

    assert_difference("AppPreference.count", 1) do
      get core_app_root_url(ri: "jp")
    end

    assert_response :success
    assert_predicate cookies[PreferenceCookieName.access(surface: :app)], :present?
    assert_predicate cookies[PreferenceCookieName.refresh(surface: :app)], :present?
  end
end
