# typed: false
# frozen_string_literal: true

require "test_helper"

# Registration has two entry points that share the same failure vocabulary: the
# sign-up path persists directly, the settings path commits through the ceremony
# contract. Every way the ceremony can fail has to answer with a distinct status
# -- a replayed or expired challenge is a bad request, a credential already
# registered is a conflict, and a failed attestation is unprocessable -- because
# the client decides whether to retry from those. Neither entry point may return
# a passkey when any of them fires.
class PasskeyRegistrationFlowRefusalsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  # The concern pulls in callbacks when included, so the harness has to be a
  # controller. ApplicationController would drag in the surface stack this is
  # deliberately outside of.
  class Harness < ActionController::Base # rubocop:disable Rails/ApplicationController
    include ::PasskeyRegistrationFlow

    attr_accessor :params, :rendered, :raise_on_consume

    def initialize
      super
      @params = ActionController::Parameters.new(challenge_id: "challenge-1")
      @rendered = []
    end

    def invoke(name, ...) = send(name, ...)

    def render(**options) = rendered << options

    def passkey_registration_actor = :actor

    def passkey_registration_log_prefix = "webauthn.registration"

    def consume_passkey_challenge!(_id, **)
      raise raise_on_consume if raise_on_consume

      :challenge
    end
  end

  def refuse(entry_point, error)
    harness = Harness.new
    harness.raise_on_consume = error
    result = harness.invoke(entry_point)
    [harness.rendered.last, result]
  end

  CHALLENGE_ERROR = Webauthn::ChallengeStore::ChallengeNotFoundError.new("replayed")
  VERIFICATION_ERROR = Webauthn::RegistrationVerifier::VerificationError.new("attestation rejected")
  WEBAUTHN_ERROR = WebAuthn::Error.new("malformed")

  # The sign-up entry point answers nil on every refusal, because its caller
  # decides what to do next from the return value. The settings entry point has
  # already rendered the response itself, so its return value carries nothing.
  {
    verify_and_create_passkey_registration!: true,
    verify_passkey_registration: false,
  }.each do |entry_point, answers_nil|
    test "#{entry_point} refuses a challenge that cannot be consumed as a bad request" do
      rendered, result = refuse(entry_point, CHALLENGE_ERROR)

      assert_equal :bad_request, rendered.fetch(:status)
      assert_equal I18n.t("errors.webauthn.challenge_invalid"), rendered.fetch(:json).fetch(:error)
      assert_nil result if answers_nil
    end

    test "#{entry_point} refuses a failed attestation as unprocessable" do
      [VERIFICATION_ERROR, WEBAUTHN_ERROR].each do |error|
        rendered, result = refuse(entry_point, error)

        assert_equal :unprocessable_content, rendered.fetch(:status), error.class.name
        assert_equal I18n.t("errors.webauthn.verification_failed"), rendered.fetch(:json).fetch(:error)
        assert_nil result if answers_nil
      end
    end

    test "#{entry_point} refuses a credential that is already registered as a conflict" do
      rendered, result = refuse(entry_point, ActiveRecord::RecordNotUnique.new("duplicate webauthn_id"))

      assert_equal :conflict, rendered.fetch(:status)
      assert_equal I18n.t("errors.webauthn.credential_already_registered"), rendered.fetch(:json).fetch(:error)
      assert_nil result if answers_nil
    end

    test "#{entry_point} refuses a missing challenge id before consuming anything" do
      harness = Harness.new
      harness.params = ActionController::Parameters.new({})

      result = harness.invoke(entry_point)

      assert_equal :bad_request, harness.rendered.last.fetch(:status)
      assert_equal I18n.t("errors.webauthn.challenge_id_required"), harness.rendered.last.fetch(:json).fetch(:error)
      assert_not result if answers_nil
    end
  end

  test "the settings entry point reports a commit refused by the ceremony contract as unprocessable" do
    rendered, = refuse(:verify_passkey_registration, IdentityPasskeyCeremonyContract::Error.new("commit refused"))

    assert_equal :unprocessable_content, rendered.fetch(:status)
    assert_equal I18n.t("errors.webauthn.verification_failed"), rendered.fetch(:json).fetch(:error)
  end

  test "a persistence failure reports the record's own messages rather than a generic one" do
    harness = Harness.new
    record = ClientPasskey.new
    record.errors.add(:webauthn_id, "is invalid")
    harness.raise_on_consume = ActiveRecord::RecordInvalid.new(record)

    assert_nil harness.invoke(:verify_and_create_passkey_registration!)
    assert_equal :unprocessable_content, harness.rendered.last.fetch(:status)
    assert_includes harness.rendered.last.fetch(:json).fetch(:error), "is invalid"
  end
end
