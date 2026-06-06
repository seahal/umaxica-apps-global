# typed: false
# frozen_string_literal: true

require "test_helper"

class Core::App::RootsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    host! ENV.fetch("CORE_SERVICE_URL", "www.jp.umaxica.app")
    get core_app_root_url(ri: "jp")

    assert_response :success
  end

  test "creates preference cookies on root" do
    host! ENV.fetch("CORE_SERVICE_URL", "www.jp.umaxica.app")

    assert_difference("AppPreference.count", 1) do
      get core_app_root_url(ri: "jp")
    end

    assert_response :success
    assert_predicate cookies[PreferenceCookieName.access(surface: :app)], :present?
    assert_predicate cookies[PreferenceCookieName.refresh(surface: :app)], :present?
  end
end
