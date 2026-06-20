# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::App::Auth::CallbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
  end

  test "returns client_id as acme_app" do
    controller = Acme::App::Auth::CallbacksController.new

    assert_equal "base-rails-rp", controller.send(:oidc_client_id)
  end

  test "callback route exists" do
    assert_routing(
      { method: :get, path: "http://#{@host}/oidc/callback" },
      { controller: "acme/app/auth/callbacks", action: "show", to: "/acme/app/auth/callbacks#show" },
    )
  end
end
