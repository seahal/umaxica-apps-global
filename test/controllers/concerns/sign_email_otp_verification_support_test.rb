# typed: false
# frozen_string_literal: true

require "test_helper"

# A step-up email code page can be reloaded with the scope and path target still
# in the query string, which is how the session is rebuilt after a token
# rotation. A request that names neither, or one the step-up store refuses, must
# report that no session was restored rather than raise into the page.
class SignEmailOtpVerificationSupportTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness(scope:, pt:, &definition)
    Class.new do
      include SignEmailOtpVerificationSupport

      define_method(:incoming_scope) { scope }
      define_method(:incoming_pt) { pt }

      attr_reader :started

      def start_step_up_session!(**arguments)
        @started = arguments
      end

      def invoke(name, ...) = send(name, ...)

      class_eval(&definition) if definition
    end.new
  end

  test "a request that names both a scope and a path target restores the session" do
    subject = harness(scope: "settings_email", pt: "signed-pt")

    assert subject.invoke(:restore_step_up_session_from_params!)
    assert_equal({ scope: "settings_email", pt_param: "signed-pt" }, subject.started)
  end

  test "a request that names neither restores nothing" do
    assert_not harness(scope: nil, pt: nil).invoke(:restore_step_up_session_from_params!)
  end

  test "a request the step-up store refuses restores nothing rather than raising" do
    subject = harness(scope: "settings_email", pt: "signed-pt") do
      def start_step_up_session!(**) = raise(ActionController::BadRequest, "invalid pt")
    end

    assert_not subject.invoke(:restore_step_up_session_from_params!)
  end
end
