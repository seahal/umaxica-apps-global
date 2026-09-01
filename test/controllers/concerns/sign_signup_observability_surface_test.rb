# typed: false
# frozen_string_literal: true

require "test_helper"

# Every sign-up audit line is attributed to a surface. Controllers that already
# know their own surface answer with it; the rest are named from their class
# path, and anything that matches neither is attributed to the app surface
# rather than left unlabelled.
class SignSignupObservabilitySurfaceTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness_class(name, surface: nil)
    Class.new do
      include SignSignupObservability

      define_singleton_method(:name) { name }

      if surface
        define_method(:sign_in_surface) { surface }
        private :sign_in_surface
      end

      def invoke(method_name, ...) = send(method_name, ...)
    end
  end

  test "a controller that knows its own surface is attributed to that surface" do
    harness = harness_class("Auth::Org::Sign::Up::EmailsController", surface: :org).new

    assert_equal :org, harness.invoke(:sign_signup_observability_surface)
  end

  test "a corporate controller without the seam is attributed from its class path" do
    harness = harness_class("Sign::Com::Sign::Up::EmailsController").new

    assert_equal :com, harness.invoke(:sign_signup_observability_surface)
  end

  test "a staff controller without the seam is attributed from its class path" do
    harness = harness_class("Sign::Org::Sign::Up::EmailsController").new

    assert_equal :org, harness.invoke(:sign_signup_observability_surface)
  end

  test "anything else is attributed to the app surface rather than left unlabelled" do
    harness = harness_class("Something::Unrelated").new

    assert_equal :app, harness.invoke(:sign_signup_observability_surface)
  end
end
