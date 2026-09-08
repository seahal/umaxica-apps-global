# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Auth
  class BaseIncludedDoTest < ActiveSupport::TestCase
    test "access_policy class_method registers policy rules" do
      klass =
        Class.new(ApplicationController) do
          extend AuthenticationBase::ClassMethods
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
          extend AuthenticationBase::ClassMethods
        end

      klass.access_policy(:public_strict, only: [:show, :index], except: [:destroy])

      rules = klass.access_policy_rules

      assert_equal %w(show index), rules.first[:only]
      assert_equal %w(destroy), rules.first[:except]
    end

    test "authentication mode declarations work" do
      klass =
        Class.new(ApplicationController) do
          extend AuthenticationBase::ClassMethods
        end

      klass.declare_authentication_mode!(:open, only: :public)
      klass.declare_authentication_mode!(:private, only: :protected)
      klass.declare_authentication_mode!(:guest, only: :guest)

      rules = klass.local_authentication_mode_rules

      assert_equal 3, rules.length
      assert_equal :open, rules[0][:mode]
      assert_equal :private, rules[1][:mode]
      assert_equal :guest, rules[2][:mode]
    end

    test "access_policy validates policy name" do
      klass =
        Class.new(ApplicationController) do
          extend AuthenticationBase::ClassMethods
        end

      assert_raises(AuthenticationBase::InvalidPolicyError) do
        klass.access_policy(:invalid_policy)
      end

      assert_raises(AuthenticationBase::InvalidPolicyError) do
        klass.access_policy(:another_invalid)
      end
    end

    test "skip_before_action :enforce_access_policy! raises SkipNotAllowedError" do
      klass =
        Class.new(ApplicationController) do
          extend AuthenticationBase::ClassMethods
        end

      assert_raises(AuthenticationBase::SkipNotAllowedError) do
        klass.skip_before_action :enforce_access_policy!
      end
    end

    test "skip_action_callback :enforce_access_policy! raises SkipNotAllowedError" do
      klass =
        Class.new(ApplicationController) do
          extend AuthenticationBase::ClassMethods
        end

      assert_raises(AuthenticationBase::SkipNotAllowedError) do
        klass.skip_action_callback(:process_action, :before, :enforce_access_policy!)
      end
    end

    test "skip_before_action allows other filters" do
      klass =
        Class.new(ApplicationController) do
          extend AuthenticationBase::ClassMethods

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
      assert_includes AuthenticationBase::VALID_POLICIES, :deny_all
      assert_includes AuthenticationBase::VALID_POLICIES, :public_strict
      assert_includes AuthenticationBase::VALID_POLICIES, :auth_required
      assert_includes AuthenticationBase::VALID_POLICIES, :guest_only
    end
  end
end
