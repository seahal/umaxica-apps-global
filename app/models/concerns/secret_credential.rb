# typed: false
# frozen_string_literal: true

module SecretCredential
  extend ActiveSupport::Concern

  SECRET_PASSWORD_LENGTH = 32

  included do
    has_secure_password algorithm: :argon2, validations: false
    validates :name, presence: true
    validates :password,
              length: {
                is: SECRET_PASSWORD_LENGTH,
                message: "must be #{SECRET_PASSWORD_LENGTH} characters",
              },
              allow_nil: true
  end

  class_methods do
    def issue!(name:, length: SECRET_PASSWORD_LENGTH, discarded_at: nil, uses: 1, status: :active, **attributes)
      raw_secret_credential = SecureRandom.base58(length)
      record_attributes = attributes.merge(name: name)
      record_attributes[:uses_remaining] = uses if supports_uses_remaining?
      record_attributes[:discarded_at] = discarded_at if discarded_at && supports_expiration?
      record = new(record_attributes)
      record[identity_secret_credential_status_id_column] = status_id_for(status)
      record.password = raw_secret_credential
      record.save!
      [record, raw_secret_credential]
    end

    def identity_secret_credential_status_class
      raise NotImplementedError, "define identity_secret_credential_status_class in the including model"
    end

    def identity_secret_credential_status_id_column
      raise NotImplementedError, "define identity_secret_credential_status_id_column in the including model"
    end

    def status_id_for(status)
      status_key = status.to_s.upcase
      case identity_secret_credential_status_class.name
      when "ClientSecretCredentialStatus"
        {
          "ACTIVE" => ClientSecretCredentialStatus::ACTIVE,
          "EXPIRED" => ClientSecretCredentialStatus::EXPIRED,
          "REVOKED" => ClientSecretCredentialStatus::REVOKED,
          "USED" => ClientSecretCredentialStatus::USED,
          "DELETED" => ClientSecretCredentialStatus::DELETED,
          "NOTHING" => ClientSecretCredentialStatus::NOTHING,
        }.fetch(status_key)
      when "OperatorSecretCredentialStatus"
        {
          "ACTIVE" => OperatorSecretCredentialStatus::ACTIVE,
          "DELETED" => OperatorSecretCredentialStatus::DELETED,
          "EXPIRED" => OperatorSecretCredentialStatus::EXPIRED,
          "REVOKED" => OperatorSecretCredentialStatus::REVOKED,
          "USED" => OperatorSecretCredentialStatus::USED,
        }.fetch(status_key)
      when "VisitorSecretCredentialStatus"
        {
          "ACTIVE" => VisitorSecretCredentialStatus::ACTIVE,
          "EXPIRED" => VisitorSecretCredentialStatus::EXPIRED,
          "REVOKED" => VisitorSecretCredentialStatus::REVOKED,
          "USED" => VisitorSecretCredentialStatus::USED,
          "DELETED" => VisitorSecretCredentialStatus::DELETED,
          "NOTHING" => VisitorSecretCredentialStatus::NOTHING,
        }.fetch(status_key)
      else
        raise KeyError,
              "Unknown identity secret_credential status class: #{identity_secret_credential_status_class.name}"
      end
    end

    def supports_uses_remaining?
      if respond_to?(:column_names)
        column_names.include?("uses_remaining")
      elsif respond_to?(:attribute_types)
        attribute_types.key?("uses_remaining")
      else
        false
      end
    end

    def supports_expiration?
      if respond_to?(:column_names)
        column_names.include?("discarded_at")
      elsif respond_to?(:attribute_types)
        attribute_types.key?("discarded_at")
      else
        false
      end
    end
  end

  def verify_and_consume!(raw_secret_credential, now: Time.current)
    with_lock do
      reload

      # Perform authentication first to maintain constant-time comparison
      auth_result = authenticate(raw_secret_credential)

      # Then check other conditions
      return false unless active?
      return false if expire_if_needed!(now: now)

      if uses_remaining_available?
        return false unless Integer(uses_remaining.to_s, 10).positive?
      end
      return false unless auth_result

      self.last_used_at = now
      if uses_remaining_available?
        self.uses_remaining -= 1
        if uses_remaining.zero?
          self[self.class.identity_secret_credential_status_id_column] = self.class.status_id_for(:used)
        end
      else
        # Fallback for secret_credentials without uses_remaining persistence: mark as used after first success.
        self[self.class.identity_secret_credential_status_id_column] = self.class.status_id_for(:used)
      end

      save!
    end

    true
  end

  def expire_if_needed!(now: Time.current)
    return false unless active?
    return false unless expired_by_time?(now)

    self[self.class.identity_secret_credential_status_id_column] = self.class.status_id_for(:expired)
    save!
    true
  end

  def active?
    secret_credential_status_id == self.class.identity_secret_credential_status_class::ACTIVE
  end

  def used?
    secret_credential_status_id == self.class.identity_secret_credential_status_class::USED
  end

  def revoked?
    secret_credential_status_id == self.class.identity_secret_credential_status_class::REVOKED
  end

  def expired?
    secret_credential_status_id == self.class.identity_secret_credential_status_class::EXPIRED
  end

  def deleted?
    secret_credential_status_id == self.class.identity_secret_credential_status_class::DELETED
  end

  private

  def secret_credential_status_id
    self[self.class.identity_secret_credential_status_id_column]
  end

  def uses_remaining_available?
    respond_to?(:uses_remaining) && self.class.supports_uses_remaining?
  end

  def expired_by_time?(now)
    return false unless respond_to?(:discarded_at)
    return false if discarded_at.nil?

    # PostgreSQL infinity/-infinity are used as sentinels for "never expires"
    # When read from DB, they may be converted to Float::INFINITY/-Float::INFINITY
    return false if discarded_at.respond_to?(:infinite?) && discarded_at.infinite?

    discarded_at <= now
  end
end
