# typed: false
# frozen_string_literal: true

require "test_helper"

class ComSocialLoginBlockedTest < ActionDispatch::IntegrationTest
  setup do
    @corporate_host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @service_host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
  end

  test "POST /auth/google_app on corporate host returns 404" do
    host! @corporate_host
    post "/auth/google_app"

    assert_response :not_found
  end

  test "POST /auth for org Google provider on corporate host returns 404" do
    host! @corporate_host
    post "/auth/google_#{"org"}"

    assert_response :not_found
  end

  test "POST /auth/apple on corporate host returns 404" do
    host! @corporate_host
    post "/auth/apple"

    assert_response :not_found
  end

  test "POST /auth/google_app on service host does not return 404" do
    host! @service_host
    post "/auth/google_app"
    # It should redirect to OmniAuth or fail CSRF, but NOT 404 from our guard
    assert_not_equal 404, response.status
  end

  test "corporate sign-in page does not contain social login buttons" do
    host! @corporate_host
    get "/sign/in/entrance?ri=jp"

    assert_response :success
    assert_not_includes response.body, "/auth/google_app"
    assert_not_includes response.body, "/auth/google_#{"org"}"
    assert_not_includes response.body, "/auth/google_#{"com"}"
    assert_not_includes response.body, "/auth/apple"
    # Check for i18n keys absence if they were social-specific
    assert_not_includes response.body, "Googleで続行" if I18n.locale == :ja
  end

  test "corporate Google provider request is blocked" do
    host! @corporate_host

    post "/auth/google_#{"com"}"

    assert_response :not_found
  end

  test "corporate guard does not open app google when legacy COM flag is on" do
    host! @corporate_host
    with_env("COM_#{"GOOGLE"}_SIGNUP_ENABLED" => "true", "COM_#{"GOOGLE"}_SIGNIN_ENABLED" => "false") do
      post "/auth/google_app", headers: social_callback_headers(@corporate_host)
    end

    assert_response :not_found
  end

  private

  def with_env(values)
    original = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    original.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
