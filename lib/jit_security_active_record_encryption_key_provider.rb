# typed: false
# frozen_string_literal: true

require "json"

# Centralized key resolution for Active Record encryption rotation.
# Uses Rails.app.creds (ENV -> credentials) for unified lookup.
module JitSecurityActiveRecordEncryptionKeyProvider
  module_function

  # Returns { current: String, previous: [String], deterministic: String, key_derivation_salt: String }.
  def fetch
    fetch_from_local
  end

  def fetch_from_local
    {
      current: required_credential(:ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY),
      previous: parse_local_previous,
      deterministic: required_credential(:ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY),
      key_derivation_salt: required_credential(:ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT),
    }
  end

  def parse_local_previous
    raw = credential_value(:ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY_PREVIOUS)
    return [] if raw.blank?

    Array(JSON.parse(raw))
  rescue JSON::ParserError
    [raw]
  end

  # Every environment must supply this key. There is deliberately no derivable
  # fallback: a key computed from public strings encrypts emails, telephone numbers,
  # birthdates, and TOTP seeds under a value anyone holding the source can recompute,
  # so the resulting ciphertext is not a security boundary. Restricting such a
  # fallback to development and test does not make it safe either, because those
  # databases still accumulate real data during manual testing and because the
  # resulting boot succeeds silently. Fail and name the missing key instead.
  def required_credential(key)
    value = credential_value(key)
    return value if value.present?

    raise KeyError,
          "missing credential: #{key} (RAILS_ENV=#{Rails.env}); " \
          "see docs/reference/active-record-encryption-rotation.md"
  end

  # Deliberately does not rescue. ActiveSupport::EncryptedFile::MissingKeyError is a
  # RuntimeError, and this is one of the earliest credentials reads at boot
  # (config/application.rb), so swallowing it here would hide an absent
  # config/credentials/<env>.key behind an unrelated failure later.
  def credential_value(key)
    Rails.app.creds.option(key)
  end
end
