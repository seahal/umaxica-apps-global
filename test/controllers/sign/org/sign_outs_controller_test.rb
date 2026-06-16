# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::SignOutsControllerTest < ActionDispatch::IntegrationTest
  test "sign org sign-out ceremony routes are retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("ID_STAFF_URL", "id.org.localhost")}/sign/out/confirmation",
        method: :get,
      )
    end
  end

  test "signed-out page renders on org sign host" do
    get sign_org_signed_out_url(ri: "jp", host: ENV.fetch("ID_STAFF_URL", "id.org.localhost"))

    assert_response :success
    assert_select "a[href=?]", sign_org_sign_in_path(ri: "jp")
  end
end
