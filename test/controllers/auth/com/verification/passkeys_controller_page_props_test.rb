# typed: false
# frozen_string_literal: true

require "test_helper"

# The corporate passkey step-up page is built from the challenge just issued and
# the scope and return target the ceremony is carrying. Both must survive onto
# the page: losing the scope would let the completed assertion clear a different
# scope than the one that was asked for.
class Auth::Com::Verification::PasskeysControllerPagePropsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness < Auth::Com::Verification::PasskeysController
    attr_accessor :params_hash, :rendered

    def params
      ActionController::Parameters.new(params_hash || {})
    end

    def incoming_scope = nil

    def incoming_pt = nil

    def form_authenticity_token = "csrf-token"

    def render(*args, **kwargs)
      self.rendered = [args, kwargs]
    end

    def invoke(name, ...) = send(name, ...)
  end

  setup do
    @harness = Harness.new
    @harness.params_hash = { ri: "jp", scope: "settings_email", pt: "signed-pt" }
    @harness.request = ActionDispatch::TestRequest.create
  end

  test "the page carries the scope, the return target and the issued challenge" do
    @harness.instance_variable_set(:@passkey_challenge_id, "challenge-1")
    @harness.instance_variable_set(:@passkey_request_options, { "challenge" => "abc" })

    props = @harness.invoke(:new_page_props)

    assert_equal "settings_email", props.dig(:form, :scope)
    assert_equal "signed-pt", props.dig(:form, :pt)
    assert_equal "challenge-1", props.dig(:form, :challenge_id)
    assert_equal({ "challenge" => "abc" }, props.dig(:form, :request_options))
    assert_includes props.dig(:back, :href), "scope=settings_email"
  end

  test "a page rendered before a challenge exists carries no request options" do
    props = @harness.invoke(:new_page_props)

    assert_nil props.dig(:form, :request_options)
  end

  test "the page is rendered as this surface's own component" do
    @harness.invoke(:render_verification_passkey_page, status: :unprocessable_content)

    assert_equal(
      Auth::Com::Verification::PasskeysController::NEW_COMPONENT,
      @harness.rendered.last.fetch(:inertia),
    )
    assert_equal :unprocessable_content, @harness.rendered.last.fetch(:status)
  end
end
