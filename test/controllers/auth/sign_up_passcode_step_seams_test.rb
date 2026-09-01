# typed: false
# frozen_string_literal: true

require "test_helper"

# The sign-up passcode step writes a credential for an account that does not
# exist yet. A rejected write must re-render the form with the raw value the
# applicant was shown, and a step reached without a pending account at all is a
# not-found rather than a crash. The requirement context is optional: a context
# that cannot be built leaves the step to the shared handling.
class Auth::SignUpPasscodeStepSeamsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness_for(controller_class, &definition)
    Class.new(controller_class) do
      attr_accessor :params_hash, :rendered, :page_status

      def params
        ActionController::Parameters.new(params_hash || {})
      end

      def session = @session_hash ||= {}

      def render(*args, **kwargs)
        self.rendered = [args, kwargs]
      end

      def render_sign_up_passcode_page(status: :ok)
        self.page_status = status
      end

      def invoke(name, ...) = send(name, ...)

      class_eval(&definition) if definition
    end.new.tap { |h| h.params_hash = { ri: "jp" } }
  end

  [
    Auth::App::Sign::Up::Check::Telephone::PasscodesController,
    Auth::Com::Sign::Up::Check::Telephone::PasscodesController,
  ].each do |klass|
    test "#{klass.name} answers a step with no pending account as not found" do
      harness = harness_for(klass) do
        def sign_up_pending_actor = nil
      end

      harness.invoke(:load_sign_up_actor)

      assert_equal :not_found, harness.rendered.last.fetch(:status)
    end

    test "#{klass.name} leaves a requirement context it cannot build to the shared handling" do
      harness = harness_for(klass)
      harness.instance_variable_set(:@sign_up_ticket, nil)
      harness.instance_variable_set(:@sign_up_actor, nil)
      refusing = ->(**) { raise ArgumentError, "context cannot be built" }

      SignUpRequirementContext.stub(:build, refusing) do
        assert_nil harness.invoke(:sign_up_requirement_context)
      end
    end
  end
end
