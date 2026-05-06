# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::PreferencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
  end

  test "should get show" do
    get sign_com_preference_url(ri: "jp")

    assert_response :success
    assert_select "a[href=?]", new_sign_com_preference_email_path(ri: "jp")
  end
end
