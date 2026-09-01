# typed: false
# frozen_string_literal: true

require "test_helper"

# Both verification concerns read the incoming scope and path target out of the
# request parameters, and both are also mixed into objects that are not serving
# a request -- the step-up harnesses and the mailer-side callers. Reading
# parameters there has to yield an empty set rather than raise, or a caller with
# no request would take the concern down instead of simply finding nothing.
class VerificationRequestParametersFallbackTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness_for(concern)
    Class.new do
      include concern

      def invoke(name, ...) = send(name, ...)
    end.new
  end

  test "the email otp support concern reads no parameters when there is no request and no params" do
    assert_empty harness_for(SignEmailOtpVerificationSupport).invoke(:request_parameters)
  end

  test "the app verification base concern reads no parameters when there is no request and no params" do
    assert_empty harness_for(SignAppVerificationBase).invoke(:request_parameters)
  end

  test "a request that is present is preferred over anything else" do
    harness = harness_for(SignEmailOtpVerificationSupport)
    harness.define_singleton_method(:request) { Struct.new(:parameters).new({ "pt" => "/settings" }) }

    assert_equal({ "pt" => "/settings" }, harness.invoke(:request_parameters))
  end
end
