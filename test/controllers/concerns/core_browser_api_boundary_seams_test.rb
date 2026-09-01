# typed: false
# frozen_string_literal: true

require "test_helper"

# The core browser API boundary derives three things from the surface it is
# mounted on: which association on the token row holds the principal, who the
# current actor is, and which policy subject authorization runs against. Getting
# any of them wrong would read one surface's principal through another surface's
# token, so they are pinned per resource type rather than exercised only through
# whichever surface a request happened to hit.
class CoreBrowserApiBoundarySeamsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness_for(resource_type)
    # The concern registers a before_action, so it can only be included into a
    # controller class, not a bare object.
    Class.new(ApplicationController) do
      include CoreBrowserApiBoundary

      define_method(:core_resource_type) { resource_type }
      private :core_resource_type

      attr_reader :rendered_problem

      def render_problem(slug, **options)
        @rendered_problem = [slug, options]
      end

      def invoke(name, ...) = send(name, ...)
    end.new
  end

  test "the token association is chosen from the resource type the surface declares" do
    assert_equal :staff, harness_for("operator").invoke(:core_token_resource_method)
    assert_equal :visitor, harness_for("visitor").invoke(:core_token_resource_method)
    assert_equal :user, harness_for("client").invoke(:core_token_resource_method)
  end

  test "an authorization failure is answered as a problem document rather than a bare status" do
    harness = harness_for("client")

    harness.invoke(:render_authorization_denied)

    assert_equal :authorization_denied, harness.rendered_problem.first
  end

  test "the current actor and policy subject come from the request-scoped actor context" do
    harness = harness_for("client")

    Actor.clear

    assert_equal :unauthenticated, harness.invoke(:current_actor).actor_type
    assert_nil harness.invoke(:current_policy_user)
  ensure
    Actor.clear
  end
end
