# typed: false
# frozen_string_literal: true

require "test_helper"

module Base
  class DomainStructureTest < ActionDispatch::IntegrationTest
    test "base/com uses Visitor authentication pattern" do
      controller = Base::Com::ApplicationController.new

      assert_includes controller.class, ::AuthenticationVisitor,
                      "Base::Com should use Visitor authentication"
      assert_includes controller.class, ::AuthorizationVisitor,
                      "Base::Com should use Visitor authorization"
      assert_includes controller.class, ::VerificationVisitor,
                      "Base::Com should use Visitor verification"
    end

    test "base/org has transparent_refresh_access_token callback" do
      callbacks = Base::Org::ApplicationController._process_action_callbacks
      before_filters = callbacks.select { |c| c.kind == :before }.map(&:filter)

      assert_includes before_filters, :transparent_refresh_access_token,
                      "Base::Org should have transparent_refresh_access_token callback"
    end

    test "base/app has oidc_sign_host method" do
      controller = Base::App::ApplicationController.new

      assert_respond_to controller, :oidc_sign_host,
                        "Base::App should have oidc_sign_host method"
    end

    test "base/app has oidc_base_host method" do
      controller = Base::App::ApplicationController.new

      assert_respond_to controller, :oidc_base_host,
                        "Base::App should have oidc_base_host method"
    end

    test "base/com has oidc_sign_host method" do
      controller = Base::Com::ApplicationController.new

      assert_respond_to controller, :oidc_sign_host,
                        "Base::Com should have oidc_sign_host method"
    end

    test "base/com has oidc_base_host method" do
      controller = Base::Com::ApplicationController.new

      assert_respond_to controller, :oidc_base_host,
                        "Base::Com should have oidc_base_host method"
    end
  end
end
