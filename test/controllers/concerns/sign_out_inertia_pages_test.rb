# typed: false
# frozen_string_literal: true

require "test_helper"

# The sign-out ceremony pages are named from the including controller's own
# controller_path, which is what stops one surface rendering another surface's
# page. The props each screen carries are the contract with the React component.
class SignOutInertiaPagesTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness
    class << self
      def controller_path = "auth/app/sign/outs"

      def before_action(*, **, &) = nil

      def after_action(*, **, &) = nil

      def helper_method(*) = nil
    end

    include SignOutInertiaPages

    attr_accessor :surface_name, :rendered, :notice_consumed

    def initialize
      @surface_name = "app"
      @rendered = nil
    end

    def t(key, **) = "t:#{key}"

    def sign_out_active_context_present? = false

    def sign_out_completed_description = "completed"

    def sign_out_home_link = { label: "home", href: "/" }

    def sign_out_confirmation_form_path = "/sign/out"

    def logout_surface_name = surface_name

    def consume_sign_out_notice
      @notice_consumed = true
      "notice"
    end

    def render(**options) = @rendered = options

    def invoke(name, ...) = send(name, ...)
  end

  setup { @harness = Harness.new }

  test "the sign-out pages are named from the including controller's own surface" do
    assert_equal "auth/app/sign/outs/complete", @harness.invoke(:sign_out_page_component, "complete")
    assert_equal "auth/app/sign/outs/unavailable", @harness.invoke(:sign_out_page_component, "unavailable")
  end

  test "the completion screen carries its heading, description and way home" do
    props = @harness.invoke(:sign_out_completion_props)

    assert_equal "t:sign.shared.sign_out.completed_title", props.fetch(:title)
    assert_equal "t:sign.shared.sign_out.completed_title", props.fetch(:heading)
    assert_equal "completed", props.fetch(:description)
    assert_equal({ label: "home", href: "/" }, props.fetch(:home_link))
  end

  test "the unavailable screen offers a retry aimed at the confirmation form" do
    props = @harness.invoke(:sign_out_unavailable_props)

    assert_equal "t:sign.shared.sign_out.unavailable_title", props.fetch(:title)
    assert_equal "/sign/out", props.fetch(:retry).fetch(:action)
    assert_equal({ label: "home", href: "/" }, props.fetch(:home_link))
  end

  test "rendering the completion screen consumes the pending sign-out notice" do
    @harness.invoke(:render_oidc_rp_logout_completion)

    assert @harness.notice_consumed
    assert_equal "auth/app/sign/outs/complete", @harness.rendered.fetch(:inertia)
    assert_equal :ok, @harness.rendered.fetch(:status)
  end

  # Only the app surface has an unavailable screen; the others fall through to the
  # completion page rather than showing a dead end.
  test "only the app surface answers an incomplete RP logout with the unavailable screen" do
    @harness.invoke(:render_oidc_rp_logout_unavailable)

    assert_equal "auth/app/sign/outs/unavailable", @harness.rendered.fetch(:inertia)
    assert_equal :unprocessable_content, @harness.rendered.fetch(:status)

    @harness.surface_name = "com"
    @harness.invoke(:render_oidc_rp_logout_unavailable)

    assert_equal "auth/app/sign/outs/complete", @harness.rendered.fetch(:inertia)
    assert_equal :ok, @harness.rendered.fetch(:status)
  end
end
