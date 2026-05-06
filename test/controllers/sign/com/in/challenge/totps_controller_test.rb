# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::In::Challenge::TotpsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
  end

  test "new redirects because totp challenge is unavailable" do
    get new_sign_com_in_challenge_totp_path(ri: "jp")

    assert_response :see_other
    assert_redirected_to new_sign_com_in_path(ri: "jp")
  end

  test "create redirects because totp challenge is unavailable" do
    post sign_com_in_challenge_totp_path(ri: "jp"), params: { totp_challenge_form: { token: "123456" } }

    assert_response :see_other
    assert_redirected_to new_sign_com_in_path(ri: "jp")
  end
end
