# typed: false
# frozen_string_literal: true

require "test_helper"

class Apex::Com::Auth::CallbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("APEX_CORPORATE_URL", "www.com.localhost")
  end

  test "returns client_id as apex_com" do
    controller = Apex::Com::Auth::CallbacksController.new

    assert_equal "apex_com", controller.send(:oidc_client_id)
  end

  test "callback route exists" do
    assert_routing(
      { method: :get, path: "http://#{@host}/auth/callback" },
      { host: @host, controller: "apex/com/auth/callbacks", action: "show" },
    )
  end
end
