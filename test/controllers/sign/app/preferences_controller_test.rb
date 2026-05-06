# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::PreferencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
  end

  test "should get show" do
    get sign_app_preference_url(ri: "jp")

    assert_response :success
    assert_select "a[href=?]", new_sign_app_preference_email_path(ri: "jp")
  end
end
