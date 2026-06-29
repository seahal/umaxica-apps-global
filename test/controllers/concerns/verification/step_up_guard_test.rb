# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Verification
  # Unit coverage for the step_up DSL. End-to-end redirect/status/flash behaviour
  # is exercised by the step-up integration tests; here we assert that the DSL
  # forwards the right arguments to the existing require_step_up! helpers.
  class StepUpGuardTest < ActiveSupport::TestCase
    self.fixture_table_names = []

    # Builds a throwaway controller-like class that records before_action
    # registrations and stubs the underlying step-up helpers.
    def build_controller(verification_scope: "settings_default")
      Class.new do
        @registrations = []

        class << self
          attr_reader :registrations

          def before_action(**options, &block)
            registrations << { options: options, block: block }
          end
        end

        include VerificationStepUpGuard

        define_method(:verification_scope) { verification_scope }

        attr_reader :calls

        def initialize
          @calls = []
        end

        def require_step_up!(**kwargs)
          @calls << [:require_step_up!, kwargs]
        end

        def require_step_up_unless_bootstrap!(**kwargs)
          @calls << [:require_step_up_unless_bootstrap!, kwargs]
        end
      end
    end

    def run_registration(klass)
      registration = klass.registrations.last
      instance = klass.new
      instance.instance_exec(&registration[:block])
      [registration[:options], instance.calls]
    end

    test "registers a before_action scoped to the given actions" do
      klass = build_controller
      klass.step_up(only: %i(edit update destroy))

      options, _calls = run_registration(klass)

      assert_equal({ only: %i(edit update destroy) }, options)
    end

    test "defaults scope to the controller verification_scope" do
      klass = build_controller(verification_scope: "settings_birthdate")
      klass.step_up(only: :show)

      _options, calls = run_registration(klass)

      assert_equal [[:require_step_up!, { scope: "settings_birthdate" }]], calls
    end

    test "uses an explicit literal scope when provided" do
      klass = build_controller
      klass.step_up(only: :destroy, scope: "social_unlink")

      _options, calls = run_registration(klass)

      assert_equal [[:require_step_up!, { scope: "social_unlink" }]], calls
    end

    test "bootstrap option routes to require_step_up_unless_bootstrap!" do
      klass = build_controller(verification_scope: "settings_email")
      klass.step_up(only: %i(new create), bootstrap: true)

      _options, calls = run_registration(klass)

      assert_equal [[:require_step_up_unless_bootstrap!, { scope: "settings_email" }]], calls
    end

    test "forwards required_aal only when given" do
      klass = build_controller
      klass.step_up(only: :show, required_aal: :aal3)

      _options, calls = run_registration(klass)

      assert_equal [[:require_step_up!, { scope: "settings_default", required_aal: :aal3 }]], calls
    end
  end
end
