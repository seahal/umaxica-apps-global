# typed: false
# frozen_string_literal: true

require "test_helper"

# After session management the client is sent back to where it came from. A
# return target that still verifies is followed; one that does not falls back to
# the surface's own identity page, so a tampered target can never redirect
# anywhere the surface did not choose.
class Auth::SignInSessionReturnPathsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness_for(controller_class, return_path:, resolved:)
    Class.new(controller_class) do
      attr_accessor :params_hash, :destination, :jump_url, :gate_consumed

      def params
        ActionController::Parameters.new(params_hash || {})
      end

      def session = @session_hash ||= {}

      def consume_session_limit_gate!
        self.gate_consumed = true
      end

      def signed_pt_token(value) = value && "signed:#{value}"

      def redirect_to_pt_destination!(value)
        self.destination = value
      end

      def redirect_to_jump_url(value, **)
        self.jump_url = value
      end

      def current_region_identifier = "jp"

      def invoke(name, ...) = send(name, ...)
    end.new.tap do |h|
      h.params_hash = { ri: "jp" }
      h.request = ActionDispatch::TestRequest.create
      h.define_singleton_method(:retrieve_pt) { return_path }
      h.define_singleton_method(:session_limit_pt) { nil }
      h.define_singleton_method(:path_from_signed_pt) { |_token| resolved }
    end
  end

  [Auth::App::Sign::In::SessionsController, Auth::Org::Sign::In::SessionsController].each do |klass|
    test "#{klass.name} follows a return target that still verifies" do
      harness = harness_for(klass, return_path: "/settings/emails", resolved: "/settings/emails")

      harness.invoke(:redirect_to_return_path)

      assert_equal "/settings/emails", harness.destination
      assert harness.gate_consumed
    end

    test "#{klass.name} falls back to its own identity page when the target no longer verifies" do
      harness = harness_for(klass, return_path: "/settings/emails", resolved: nil)

      harness.invoke(:redirect_to_return_path)

      assert_includes harness.destination, "/identity"
    end

    test "#{klass.name} hands off through the jump gateway when there is no target at all" do
      harness = harness_for(klass, return_path: nil, resolved: nil)

      harness.invoke(:redirect_to_return_path)

      assert_includes harness.jump_url, "/identity"
    end
  end
end
