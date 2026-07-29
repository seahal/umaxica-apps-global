# typed: false
# frozen_string_literal: true

require "test_helper"

class AccountStandingRouteContractTest < ActionDispatch::IntegrationTest
  test "app account standing uses the app identity boundary" do
    route = Rails.application.routes.recognize_path("http://base.app.localhost/identity/standing?ri=jp", method: :get)

    assert_equal({ controller: "base/app/identity/standings", action: "show" }, route)
  end

  test "com account standing uses the com identity boundary" do
    route = Rails.application.routes.recognize_path("http://base.com.localhost/identity/standing?ri=jp", method: :get)

    assert_equal({ controller: "base/com/identity/standings", action: "show" }, route)
  end

  test "org account standing uses the org identity boundary" do
    route = Rails.application.routes.recognize_path("http://base.org.localhost/identity/standing?ri=jp", method: :get)

    assert_equal({ controller: "base/org/identity/standings", action: "show" }, route)
  end

  test "app and com recovery routes are independent no-session resources" do
    app_route = Rails.application.routes.recognize_path(
      "http://base.app.localhost/identity/recovery/session/new?ri=jp", method: :get,
    )
    com_route = Rails.application.routes.recognize_path(
      "http://base.com.localhost/identity/recovery/completion?ri=jp", method: :post,
    )

    assert_equal({ controller: "base/app/identity/recovery/sessions", action: "new" }, app_route)
    assert_equal({ controller: "base/com/identity/recovery/completions", action: "create" }, com_route)
  end
end
