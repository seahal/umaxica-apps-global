# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::Org::Auth::CallbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
  end

  test "returns client_id as acme_org" do
    controller = Acme::Org::Auth::CallbacksController.new

    assert_equal "base-rails-rp", controller.send(:oidc_client_id)
  end

  test "callback route exists" do
    assert_routing(
      { method: :get, path: "http://#{@host}/auth/callback" },
      { controller: "acme/org/auth/callbacks", action: "show" },
    )
  end
end
