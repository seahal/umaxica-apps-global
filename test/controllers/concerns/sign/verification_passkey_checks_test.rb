# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignVerificationPasskeyChecksTest < ActiveSupport::TestCase
  class Harness
    include SignVerificationPasskeyChecks

    attr_accessor :verification_errors, :verification_params_value, :scope_records, :passkey_model_class

    def initialize
      @verification_params_value = {}
      @scope_records = []
      @passkey_model_class = Class.new
    end

    def verification_passkeys_scope
      Struct.new(:records) do
        define_method(:active) do
          records
        end

        define_method(:map) do |&block|
          records.map(&block)
        end
      end.new(scope_records)
    end

    def verification_passkey_model
      passkey_model_class
    end

    def passkey_actor_matches?(_passkey)
      true
    end

    def verification_no_passkey_i18n_key
      "errors.webauthn.no_passkey"
    end

    def create_authentication_challenge(allow_credentials:)
      ["challenge-1", { allowCredentials: allow_credentials }]
    end

    def verification_params
      verification_params_value.with_indifferent_access
    end

    def with_challenge(_challenge_id, purpose:)
      raise RuntimeError, "wrong purpose" unless purpose == :authentication

      yield "challenge"
    end

    def webauthn_relying_party
      "example.test"
    end
  end

  test "prepare_passkey_challenge returns false when no passkeys exist" do
    harness = Harness.new

    assert_not harness.send(:prepare_passkey_challenge!)
    assert_predicate harness.verification_errors, :present?
  end

  test "prepare_passkey_challenge stores challenge when passkeys exist" do
    harness = Harness.new
    harness.scope_records = [Struct.new(:webauthn_id).new("cred-1")]

    assert harness.send(:prepare_passkey_challenge!)
    assert_equal "challenge-1", harness.instance_variable_get(:@passkey_challenge_id)
    assert_equal [{ id: "cred-1" }], harness.instance_variable_get(:@passkey_request_options)[:allowCredentials]
  end

  test "verify_passkey handles missing params, missing passkey, success, and parse errors" do
    harness = Harness.new

    assert_not harness.send(:verify_passkey!)
    assert_equal ["パスキー認証データが不足しています"], harness.verification_errors

    credential = Struct.new(:id, :sign_count) do
      define_method(:verify) do |*|
        true
      end
    end.new("cred-1", 7)
    passkey_model =
      Class.new do
        class << self
          define_method(:record) do
            @record
          end

          define_method(:record=) do |value|
            @record = value
          end

          define_method(:find_by) do |webauthn_id:|
            @record if @record&.webauthn_id == webauthn_id
          end
        end
      end

    harness.passkey_model_class = passkey_model
    harness.verification_params_value = { challenge_id: "challenge-1", credential_json: { id: "cred-1" }.to_json }

    WebAuthn::Credential.stub(:from_get, credential) do
      assert_not harness.send(:verify_passkey!)
      assert_equal [I18n.t("errors.webauthn.credential_not_found")], harness.verification_errors
    end

    passkey = Struct.new(:webauthn_id, :public_key, :sign_count) do
      define_method(:update!) do |**kwargs|
        kwargs
      end
    end.new("cred-1", "public-key", 1)
    passkey_model.record = passkey

    passkey.define_singleton_method(:update!) do |**kwargs|
      @updated_payload = kwargs
    end
    passkey.define_singleton_method(:updated_payload) { @updated_payload }

    WebAuthn::Credential.stub(:from_get, credential) do
      assert harness.send(:verify_passkey!)
    end

    assert_equal({ sign_count: 7 }, passkey.updated_payload)

    harness.verification_params_value = { challenge_id: "challenge-1", credential_json: "{" }

    assert_not harness.send(:verify_passkey!)
    assert_equal [I18n.t("errors.webauthn.verification_failed")], harness.verification_errors
  end
end
