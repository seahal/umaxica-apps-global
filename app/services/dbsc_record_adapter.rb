# typed: false
# frozen_string_literal: true

require "jwt"

module DbscRecordAdapter
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

  def dbsc_public_key(record)
    raw_key = normalize_public_key(record.dbsc_public_key)
    return nil if raw_key.blank?

    jwk = JWT::JWK.import(raw_key)
    return jwk.public_key if jwk.respond_to?(:public_key)
    return jwk.verify_key if jwk.respond_to?(:verify_key)

    nil
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
