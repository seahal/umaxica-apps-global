# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Com::Auth::CallbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("BASE_CORPORATE_URL")
  end

  test "returns the shared browser RP client_id" do
    controller = Base::Com::Auth::CallbacksController.new

    assert_equal "base-rails-rp", controller.send(:oidc_client_id)
  end

  test "callback route exists" do
    assert_routing(
      { method: :get, path: "http://#{@host}/oidc/callback" },
      { controller: "base/com/auth/callbacks", action: "show", to: "/base/com/auth/callbacks#show" },
    )
  end
end
