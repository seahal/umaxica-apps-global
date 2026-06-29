# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Base::App::Auth::CallbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
  end

  test "returns the shared browser RP client_id" do
    controller = Base::App::Auth::CallbacksController.new

    assert_equal "base-rails-rp", controller.send(:oidc_client_id)
  end

  test "callback route exists" do
    assert_routing(
      { method: :get, path: "http://#{@host}/oidc/callback" },
      { controller: "base/app/auth/callbacks", action: "show", to: "/base/app/auth/callbacks#show" },
    )
  end
end
