# typed: false
# frozen_string_literal: true

module IdentifierDetection
  extend ActiveSupport::Concern

  private

  def detect_identifier_type(identifier)
    return :unknown if identifier.blank?

    return :email if identifier.include?("@")
    return :telephone if identifier.include?("+")

    :unknown
  end

  def identity_email_model
    UserEmail
  end

  def identity_telephone_model
    UserTelephone
  end

  def identity_from_email_record(record)
    record&.respond_to?(:user) ? record.user : nil
  end

  def identity_from_telephone_record(record)
    record&.respond_to?(:user) ? record.user : nil
  end

  def find_user_by_identifier(identifier)
    case detect_identifier_type(identifier.to_s.strip)
    when :email
      normalized = validate_and_normalize_email(identifier.strip)
      return nil if normalized.blank?

      digest = IdentifierBlindIndex.bidx_for_email(normalized)
      return nil if digest.blank?

      resource = identity_from_email_record(identity_email_model.find_by(address_digest: digest))
      resource if resource&.login_allowed?
    when :telephone
      normalized = TelephoneNormalization.normalize_to_e164(identifier.strip)
      return nil if normalized.blank?

      digest = IdentifierBlindIndex.bidx_for_telephone(normalized)
      return nil if digest.blank?

      resource = identity_from_telephone_record(identity_telephone_model.find_by(number_digest: digest))
      resource if resource&.login_allowed?
    end
  end
end
