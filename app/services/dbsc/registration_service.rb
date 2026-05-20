# typed: false
# frozen_string_literal: true

module Dbsc
  # Completes DBSC registration by validating a proof and storing the binding key.
  class RegistrationService < ApplicationService
    def initialize(record:, proof:, now: Time.current, session_id: nil, expected_audience: nil)
      super
      @record = record
      @proof = HeaderParser.string_value(proof)
      @now = now
      @session_id = session_id.presence || record&.dbsc_session_id.presence || SecureRandom.urlsafe_base64(24)
      @expected_audience = expected_audience
    end

    def call
      return failure("record_missing") if record.blank?

      validation = validate_proof
      return failure(validation.error_code, message: validation.message) unless validation.ok

      header = validation.header
      jwk = RecordAdapter.normalize_public_key(header["jwk"])
      return failure("missing_public_key") if jwk.blank?

      verify_key = JWT::JWK.import(jwk).public_key
      signature = proof_validator.verify_signature(verify_key, header["alg"])
      return failure("invalid_proof", message: signature.message) unless signature.ok

      record.with_lock do
        record.update!(
          RecordAdapter.binding_method_attribute(record) => RecordAdapter.binding_method_class(record)::DBSC,
          RecordAdapter.dbsc_status_attribute(record) => RecordAdapter.dbsc_status_class(record)::ACTIVE,
          :dbsc_session_id => session_id,
          :dbsc_public_key => jwk,
          :dbsc_challenge => nil,
          :dbsc_challenge_issued_at => nil,
        )
      end

      { ok: true, session_id: session_id, record: record }
    rescue JWT::JWKError, JSON::ParserError, ArgumentError => e
      failure("invalid_proof", message: e.message)
    end

    private

    attr_reader :record, :proof, :now, :session_id, :expected_audience

    def validate_proof
      proof_validator.call
    end

    def proof_validator
      @proof_validator ||= ProofValidator.new(
        proof: proof,
        challenge: record.dbsc_challenge,
        challenge_issued_at: record.dbsc_challenge_issued_at,
        now: now,
        expected_audience: expected_audience,
      )
    end

    def failure(error_code, message: nil)
      { ok: false, error_code: error_code, message: message }
    end
  end
end
