# typed: false
# frozen_string_literal: true

require "test_helper"

# Two sign-up sequencing seams. The explicit-step gate decides whether a step may
# be answered at all, and the contact-OTP support decides what happens when the
# state machine reports a transition the step did not ask for -- that has to be
# recorded and refused rather than treated as the expected advance.
class SignUpStepAndOtpSeamsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness(concern, &definition)
    Class.new do
      include concern

      attr_reader :redirected

      def redirect_to(*args, **kwargs)
        @redirected = [args, kwargs]
      end

      def invoke(name, ...) = send(name, ...)

      class_eval(&definition) if definition
    end.new
  end

  test "a gate that names a redirect stops the step and follows it" do
    gate = Struct.new(:success?, :redirect?, :redirect_to, keyword_init: true)
      .new(success?: true, redirect?: true, redirect_to: "/sign/up/telephone")
    support = harness(SignUpExplicitStepControllerSupport)

    assert_not support.invoke(:load_gate_context!, gate)
    assert_equal [["/sign/up/telephone"], {}], support.redirected
  end

  test "a transition the step did not ask for is recorded and refused" do
    support = harness(SignUpContactOtpControllerSupport) do
      def sign_up_family = "email"

      def sign_up_surface = :app
    end
    support.instance_variable_set(:@sign_up_ticket, nil)
    result = Struct.new(:status, :next_event).new(:ok, :finalize)
    recorded = []

    Rails.logger.stub(:warn, ->(*args, &block) { recorded << (args.first || block&.call).to_s }) do
      refused = support.invoke(:unexpected_sign_up_otp_transition, result, :clear_requirement)

      assert_equal :invalid_transition, refused.status
    end

    assert(recorded.any? { |line| line.include?("sign.signup.email.otp.transition_unexpected") })
  end
end
