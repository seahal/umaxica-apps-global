# typed: false
# frozen_string_literal: true

require "test_helper"

# Small seams the passkey settings controller supplies to the shared
# registration flow: where a completed registration returns to, where a
# recovery-passcode reveal is read, and what a rejected edit says. Each is a
# per-surface value, so reading the wrong one would send an app-surface client
# to another surface's page.
class Auth::App::Settings::PasskeysControllerSeamsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness < Auth::App::Settings::PasskeysController
    attr_accessor :params_hash

    def params
      ActionController::Parameters.new(params_hash || {})
    end

    def invoke(name, ...) = send(name, ...)
  end

  setup do
    @harness = Harness.new
    @harness.params_hash = { ri: "jp" }
    @harness.request = ActionDispatch::TestRequest.create
  end

  test "a completed registration returns to this surface's own passkey settings page" do
    url = URI.parse(@harness.invoke(:passkey_registration_redirect_url))

    assert_equal ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), url.host
    assert_equal "/settings/passkeys", url.path
  end

  test "a recovery passcode reveal is read from the base identity surface" do
    url = URI.parse(@harness.invoke(:recovery_passcode_reveal_redirect_url, "reveal-token"))

    assert_includes url.query, "token=reveal-token"
  end

  test "a rejected passkey edit is summarised by how many errors it carries" do
    passkey = ClientPasskey.new
    @harness.instance_variable_set(:@passkey, passkey)

    assert_nil @harness.invoke(:passkey_error_header)

    passkey.errors.add(:description, :blank)

    assert_equal I18n.t("errors.messages.validation_errors", count: 1),
                 @harness.invoke(:passkey_error_header)
  end

  test "a json caller that has not verified is told so rather than redirected" do
    assert_equal I18n.t("errors.webauthn.verification_required"),
                 @harness.invoke(:passkey_verification_required_message)
  end
end
