# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Sign::OutsControllerTest < ActionDispatch::IntegrationTest
  test "sign com sign-out ceremony routes are retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost")}/sign/out/confirmation",
        method: :get,
      )
    end
  end

  test "signed-out page renders on com sign host" do
    get sign_com_sign_out_url(ri: "jp", host: ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost"))

    assert_response :success
    assert_select "a[href=?]", sign_com_sign_in_path(ri: "jp")
  end
end
