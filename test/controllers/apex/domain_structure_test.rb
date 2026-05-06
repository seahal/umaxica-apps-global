# typed: false
# frozen_string_literal: true

require "test_helper"

module Apex
  class DomainStructureTest < ActionDispatch::IntegrationTest
    test "apex/com uses Customer authentication pattern" do
      controller = Apex::Com::ApplicationController.new

      assert_includes controller.class, ::Authentication::Customer,
                      "Apex::Com should use Customer authentication"
      assert_includes controller.class, ::Authorization::Customer,
                      "Apex::Com should use Customer authorization"
      assert_includes controller.class, ::Verification::Customer,
                      "Apex::Com should use Customer verification"
    end

    test "apex/org has transparent_refresh_access_token callback" do
      callbacks = Apex::Org::ApplicationController._process_action_callbacks
      before_filters = callbacks.select { |c| c.kind == :before }.map(&:filter)

      assert_includes before_filters, :transparent_refresh_access_token,
                      "Apex::Org should have transparent_refresh_access_token callback"
    end

    test "apex/app has oidc_sign_host method" do
      controller = Apex::App::ApplicationController.new

      assert_respond_to controller, :oidc_sign_host,
                        "Apex::App should have oidc_sign_host method"
    end

    test "apex/com has oidc_sign_host method" do
      controller = Apex::Com::ApplicationController.new

      assert_respond_to controller, :oidc_sign_host,
                        "Apex::Com should have oidc_sign_host method"
    end
  end
end
