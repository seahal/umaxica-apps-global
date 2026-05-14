# typed: false
# frozen_string_literal: true

require "test_helper"

class Apex::App::Auth::CallbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("APEX_SERVICE_URL", "www.app.localhost")
  end

  test "returns client_id as apex_app" do
    controller = Apex::App::Auth::CallbacksController.new

    assert_equal "apex_app", controller.send(:oidc_client_id)
  end

  test "callback route exists" do
    assert_routing(
      { method: :get, path: "http://#{@host}/auth/callback" },
      { controller: "apex/app/auth/callbacks", action: "show" },
    )
  end
end
