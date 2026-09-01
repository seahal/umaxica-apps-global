# typed: false
# frozen_string_literal: true

require "test_helper"

# A second group of narrow seams shared across surfaces. Each is a decision the
# surrounding controller delegates: which template answers a suspended sign-up,
# where the ceremony reference lives between the start and the callback, and
# what a signed redirect target resolves to when it cannot be trusted.
class SharedSeamFallbacksTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness(concern, &definition)
    Class.new do
      include concern

      attr_reader :rendered

      def render(*args, **kwargs)
        @rendered = [args, kwargs]
      end

      def invoke(name, ...) = send(name, ...)

      class_eval(&definition) if definition
    end.new
  end

  test "a suspended sign-up is answered by the surface's own entry page with a service-unavailable status" do
    guard = harness(SignUpSuspensionGuard) { def sign_up_surface = :com }

    assert_equal "auth/com/sign_ups/new", guard.invoke(:suspended_sign_up_template)

    guard.invoke(:render_suspended_sign_up!)

    assert_equal [["auth/com/sign_ups/new"], { status: :service_unavailable }], guard.rendered
  end

  test "the external authentication ceremony reference is written to and consumed from the session" do
    endpoint = harness(ExternalAuthenticationEndpoint) do
      def session = @session ||= {}
    end

    endpoint.invoke(:store_external_authentication_ceremony_reference, "ceremony-1")

    assert_equal "ceremony-1", endpoint.invoke(:consume_external_authentication_ceremony_reference)
    assert_nil endpoint.invoke(:consume_external_authentication_ceremony_reference)
  end

  test "a resolver result with no resource is not a success" do
    result = AuthenticationCurrentResourceResolver::Result.new(resource: nil)

    assert_not result.success?
    assert_predicate AuthenticationCurrentResourceResolver::Result.new(resource: Object.new), :success?
  end
end
