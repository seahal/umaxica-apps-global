# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Base::Com::Oidc::CallbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost")
  end

  test "returns the shared browser RP client_id" do
    controller = Base::Com::Oidc::CallbacksController.new

    assert_equal "base-rails-rp", controller.send(:oidc_client_id)
  end

  test "callback route exists" do
    assert_routing(
      { method: :get, path: "http://#{@host}/oidc/callback" },
      { controller: "base/com/oidc/callbacks", action: "show" },
    )
  end
end
