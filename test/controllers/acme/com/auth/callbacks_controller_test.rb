# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::Com::Auth::CallbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
  end

  test "returns client_id as acme_com" do
    controller = Acme::Com::Auth::CallbacksController.new

    assert_equal "base-rails-rp", controller.send(:oidc_client_id)
  end

  test "callback route exists" do
    assert_routing(
      { method: :get, path: "http://#{@host}/auth/callback" },
      { controller: "acme/com/auth/callbacks", action: "show" },
    )
  end
end
