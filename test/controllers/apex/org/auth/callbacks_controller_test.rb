# typed: false
# frozen_string_literal: true

require "test_helper"

class Apex::Org::Auth::CallbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("APEX_STAFF_URL", "www.org.localhost")
  end

  test "returns client_id as apex_org" do
    controller = Apex::Org::Auth::CallbacksController.new

    assert_equal "apex_org", controller.send(:oidc_client_id)
  end

  test "callback route exists" do
    assert_routing(
      { method: :get, path: "http://#{@host}/auth/callback" },
      { controller: "apex/org/auth/callbacks", action: "show" },
    )
  end
end
