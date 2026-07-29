# typed: false
# frozen_string_literal: true

require "jwt"

module DbscRecordAdapter
  # Raised when a stored DBSC public key cannot be resolved into a verification
  # key. This is server-side state corruption, not a bad client proof, and it
  # must stay distinguishable from a failed signature check: the two have
  # opposite remediations.
  class PublicKeyError < StandardError; end

  module_function

  def binding_method_attribute(record)
    record.class.dbsc_binding_method_attribute_name
  rescue NoMethodError
    raise ArgumentError, "Unsupported DBSC binding method attribute for #{record.class.name}"
  end

  def dbsc_status_attribute(record)
    record.class.dbsc_status_attribute_name
  rescue NoMethodError
    raise ArgumentError, "Unsupported DBSC status attribute for #{record.class.name}"
  end

  def binding_method_class(record)
    record.class.dbsc_binding_method_class
  rescue NoMethodError
    raise ArgumentError, "Unsupported DBSC binding method class for #{record.class.name}"
  end

  def dbsc_status_class(record)
    record.class.dbsc_status_class
  rescue NoMethodError
    raise ArgumentError, "Unsupported DBSC status class for #{record.class.name}"
  end

  # DBSC binds a session to a key the device holds privately, so only asymmetric
  # key types are usable. A symmetric JWK ("oct") would make the stored
  # "public" key identical to the signing secret, letting whoever supplied it
  # mint valid proofs from any device and defeating the binding entirely.
  ASYMMETRIC_KEY_TYPES = %w(EC RSA OKP).freeze

  # Resolves the stored JWK into a verification key. Raises rather than
  # returning nil so the caller never hands a keyless value to JWT.decode, and
  # so an unusable stored key is reported as such instead of being folded into
  # the generic proof-verification failure. The sibling resolvers above raise
  # ArgumentError for the same reason.
  def dbsc_public_key(record)
    raw_key =
      begin
        normalize_public_key(record.dbsc_public_key)
      rescue JSON::ParserError => e
        raise PublicKeyError, "stored DBSC public key is not valid JSON: #{e.message}"
      end

    verification_key_from_jwk(raw_key, source: "stored DBSC public key")
  end

  # Shared by registration (client-supplied JWK) and verification (stored JWK)
  # so both enforce the same key-type contract.
  def verification_key_from_jwk(raw_key, source:)
    raise PublicKeyError, "#{source} is not a parsable JWK" if raw_key.blank?

    key_type = raw_key["kty"].to_s
    unless ASYMMETRIC_KEY_TYPES.include?(key_type)
      raise PublicKeyError, "#{source} must be an asymmetric JWK (kty=#{key_type.inspect})"
    end

    jwk =
      begin
        JWT::JWK.import(raw_key)
      rescue JWT::JWKError => e
        raise PublicKeyError, "#{source} is not an importable JWK: #{e.message}"
      end
    return jwk.public_key if jwk.respond_to?(:public_key)
    return jwk.verify_key if jwk.respond_to?(:verify_key)

    raise PublicKeyError, "#{source} exposes no verification key (kty=#{key_type.inspect})"
  end

  def normalize_public_key(public_key)
    return if public_key.blank?

    parsed =
      case public_key
      when String
        JSON.parse(public_key)
      when Hash
        public_key
      else
        public_key.respond_to?(:to_h) ? public_key.to_h : nil
      end

    parsed&.deep_stringify_keys
  end
end
