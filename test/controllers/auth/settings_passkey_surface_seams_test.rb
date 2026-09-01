# typed: false
# frozen_string_literal: true

require "test_helper"

# The com and org passkey settings controllers supply the same seams as the app
# surface, each pointing at its own host. Reading the wrong one would send a
# staff or corporate client to the end-user surface after registering a
# credential, so the per-surface values are pinned directly.
class Auth::SettingsPasskeySurfaceSeamsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness_for(controller_class)
    Class.new(controller_class) do
      attr_accessor :params_hash

      def params
        ActionController::Parameters.new(params_hash || {})
      end

      def render(*args, **kwargs)
        @rendered = [args, kwargs]
      end

      attr_reader :rendered

      def invoke(name, ...) = send(name, ...)
    end.new.tap do |harness|
      harness.params_hash = { ri: "jp" }
      harness.request = ActionDispatch::TestRequest.create
    end
  end

  test "the corporate surface returns to its own passkey settings page" do
    url = URI.parse(harness_for(Auth::Com::Settings::PasskeysController).invoke(:passkey_registration_redirect_url))

    assert_equal ENV.fetch("PRIVATE_AUTH_CORPORATE_URL"), url.host
    assert_equal "/settings/passkeys", url.path
  end

  test "the staff surface returns to its own passkey settings page" do
    url = URI.parse(harness_for(Auth::Org::Settings::PasskeysController).invoke(:passkey_registration_redirect_url))

    assert_equal "/settings/passkeys", url.path
  end

  test "the staff surface answers a completed registration directly, with no passcode top-up" do
    harness = harness_for(Auth::Org::Settings::PasskeysController)
    passkey = OperatorPasskey.new

    harness.invoke(:render_verification_success, passkey)

    assert_equal "ok", harness.rendered.last.fetch(:json).fetch(:status)
  end

  test "the staff recovery passcode setup page is on the staff identity surface" do
    url = URI.parse(harness_for(Auth::Org::Settings::PasskeysController).invoke(:recovery_passcode_setup_url))

    assert_includes url.path, "/identity/secrets"
  end
end
