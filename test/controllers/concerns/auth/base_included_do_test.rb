# typed: false
# frozen_string_literal: true

require "test_helper"

module Auth
  class BaseIncludedDoTest < ActiveSupport::TestCase
    class BaseHarness < ApplicationController
      include Authentication::Base

      def resource_type = "user"

      def resource_class = Client

      def token_class = ClientToken

      def audit_class = ClientChronicle

      def resource_foreign_key = :user_id

      def sign_in_url_with_return(_return_to) = "/sign/in"

      def am_i_user? = true

      def am_i_staff? = false

      def am_i_owner? = false
    end

    test "included do includes Sign::ErrorResponses module" do
      assert_includes BaseHarness.included_modules, Sign::ErrorResponses,
                      "BaseHarness should include Sign::ErrorResponses"
    end

    test "included do includes ActionPolicy controller support" do
      assert_includes BaseHarness.included_modules, ActionPolicy::Controller,
                      "BaseHarness should route access policy decisions through Action Policy"
    end

    test "included do includes SessionLimitGate module" do
      assert_includes BaseHarness.included_modules, SessionLimitGate,
                      "BaseHarness should include SessionLimitGate"
    end

    test "included do includes Common::Redirect module" do
      assert_includes BaseHarness.included_modules, Common::Redirect,
                      "BaseHarness should include Common::Redirect"
    end

    test "helper_method current_account is defined on controller" do
      assert BaseHarness.method_defined?(:current_account),
             "BaseHarness should have current_account method defined"
    end

    test "helper_method current_session_public_id is defined on controller" do
      assert BaseHarness.method_defined?(:current_session_public_id),
             "BaseHarness should have current_session_public_id method defined"
    end

    test "helper_method current_session_restricted? is defined on controller" do
      assert BaseHarness.private_method_defined?(:current_session_restricted?),
             "BaseHarness should have current_session_restricted? private method defined"
    end

    test "access_policy class_method registers policy rules" do
      klass =
        Class.new(ApplicationController) do
          extend Authentication::Base::ClassMethods
        end

      klass.access_policy(:auth_required, only: :index)

      rules = klass.access_policy_rules

      assert_equal 1, rules.length
      assert_equal :auth_required, rules.first[:policy]
      assert_equal ["index"], rules.first[:only]
    end

    test "access_policy accepts only and except options" do
      klass =
        Class.new(ApplicationController) do
          extend Authentication::Base::ClassMethods
        end

      klass.access_policy(:public_strict, only: [:show, :index], except: [:destroy])

      rules = klass.access_policy_rules

      assert_equal %w(show index), rules.first[:only]
      assert_equal %w(destroy), rules.first[:except]
    end

    test "authentication mode declarations work" do
      klass =
        Class.new(ApplicationController) do
          extend Authentication::Base::ClassMethods
        end

      klass.declare_authentication_mode! :open, only: :public
      klass.declare_authentication_mode! :private, only: :protected
      klass.declare_authentication_mode! :guest, only: :guest

      rules = klass.local_authentication_mode_rules

      assert_equal 3, rules.length
      assert_equal :open, rules[0][:mode]
      assert_equal :private, rules[1][:mode]
      assert_equal :guest, rules[2][:mode]
    end

    test "enforce_access_policy delegates declared authentication mode to Authentication::AccessPolicy" do
      controller = BaseHarness.new
      controller.define_singleton_method(:action_name) { "index" }
      controller.define_singleton_method(:logged_in?) { true }
      controller.define_singleton_method(:current_resource) { nil }

      calls = []
      controller.define_singleton_method(:access_policy_allows?) do |rule, context|
        calls << [rule, context]
        true
      end

      BaseHarness.declare_authentication_mode! :private, only: :index

      assert controller.send(:enforce_access_policy!)
      assert_equal :auth_required?, calls.first.first
      assert_instance_of Authentication::Base::AccessPolicyContext, calls.first.last
      assert_equal :auth_required, calls.first.last.policy
    ensure
      Authentication::Base::ACCESS_POLICY_RULES.delete(BaseHarness)
      BaseHarness.remove_instance_variable(:@authentication_mode_rules) if BaseHarness.instance_variable_defined?(:@authentication_mode_rules)
    end

    test "access_policy validates policy name" do
      klass =
        Class.new(ApplicationController) do
          extend Authentication::Base::ClassMethods
        end

      assert_raises(Authentication::Base::InvalidPolicyError) do
        klass.access_policy(:invalid_policy)
      end

      assert_raises(Authentication::Base::InvalidPolicyError) do
        klass.access_policy(:another_invalid)
      end
    end

    test "skip_before_action :enforce_access_policy! raises SkipNotAllowedError" do
      klass =
        Class.new(ApplicationController) do
          extend Authentication::Base::ClassMethods
        end

      assert_raises(Authentication::Base::SkipNotAllowedError) do
        klass.skip_before_action :enforce_access_policy!
      end
    end

    test "skip_action_callback :enforce_access_policy! raises SkipNotAllowedError" do
      klass =
        Class.new(ApplicationController) do
          extend Authentication::Base::ClassMethods
        end

      assert_raises(Authentication::Base::SkipNotAllowedError) do
        klass.skip_action_callback(:process_action, :before, :enforce_access_policy!)
      end
    end

    test "skip_before_action allows other filters" do
      klass =
        Class.new(ApplicationController) do
          extend Authentication::Base::ClassMethods

          before_action :some_callback

          define_method(:some_callback) do
            # Required by before_action
          end
        end

      assert_nothing_raised do
        klass.skip_before_action :some_callback
      end
    end

    test "VALID_POLICIES contains expected values" do
      assert_includes Authentication::Base::VALID_POLICIES, :deny_all
      assert_includes Authentication::Base::VALID_POLICIES, :public_strict
      assert_includes Authentication::Base::VALID_POLICIES, :auth_required
      assert_includes Authentication::Base::VALID_POLICIES, :guest_only
    end
  end
end
