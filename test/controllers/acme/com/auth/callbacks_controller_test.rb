# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::Com::Auth::CallbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
  end

  test "returns the shared browser RP client_id" do
    controller = Acme::Com::Auth::CallbacksController.new

    assert_equal "base-rails-rp", controller.send(:oidc_client_id)
  end

  test "callback route exists" do
    assert_routing(
      { method: :get, path: "http://#{@host}/oidc/callback" },
      { controller: "acme/com/auth/callbacks", action: "show", to: "/acme/com/auth/callbacks#show" },
    )
  end
end
