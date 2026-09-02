# typed: false
# frozen_string_literal: true

require "test_helper"

# Minting passkey registration options depends on a relying-party configuration
# each surface supplies. A surface with none must answer the browser with the
# shared options error rather than a 500, and the reveal purpose a completed
# registration writes under is per surface so one surface's passcodes can never
# be revealed through another's link.
class PasskeyRegistrationFlowOptionsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness(&definition)
    Class.new do
      include PasskeyRegistrationFlow

      attr_reader :rendered

      def render(*args, **kwargs)
        @rendered = [args, kwargs]
      end

      def passkey_registration_actor = nil

      def passkey_registration_existing_credentials = []

      def passkey_registration_log_prefix = "settings.passkey"

      def invoke(name, ...) = send(name, ...)

      class_eval(&definition) if definition
    end.new
  end

  test "a surface with no relying party configured answers with the shared options error" do
    subject =
      harness do
        def issue_passkey_registration_challenge(**)
          raise Webauthn::RelyingPartyConfigResolver::MissingConfigurationError, "rp_id missing"
        end
      end
    recorded = []

    Rails.logger.stub(:error, ->(*args, &block) { recorded << (args.first || block&.call).to_s }) do
      subject.invoke(:render_passkey_registration_options)
    end

    assert_equal I18n.t("errors.webauthn.options_failed"), subject.rendered.last.fetch(:json).fetch(:error)
    assert_equal :unprocessable_content, subject.rendered.last.fetch(:status)
    assert(recorded.any? { |line| line.include?("settings.passkey.options_failed") })
  end

  test "the recovery reveal purpose is scoped to the surface that issued the passcodes" do
    purposes =
      %i(app com org).to_h do |surface_key|
        subject =
          harness do
            define_method(:webauthn_surface) { Struct.new(:key).new(surface_key) }
          end

        [surface_key, subject.invoke(:recovery_passcode_reveal_purpose)]
      end

    assert_equal "client.recovery_secret_credential", purposes.fetch(:app)
    assert_equal "visitor.recovery_secret_credential", purposes.fetch(:com)
    assert_equal "org.recovery_passcodes", purposes.fetch(:org)
  end
end
