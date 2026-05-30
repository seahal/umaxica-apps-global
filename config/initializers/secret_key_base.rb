# typed: false
# frozen_string_literal: true

# SECRET_KEY_BASE rotation support.
#
# Production: Fetches current + previous keys from AWS Secrets Manager.
# Dev/Test:   Falls back to ENV["SECRET_KEY_BASE"] or Rails credentials.
#
# Secrets Manager JSON format:
#   { "current": "the_current_key", "previous": ["old_key_1", "old_key_2"] }
#
# Required env var (production only):
#   SECRET_KEY_BASE_SECRET_ID - The Secrets Manager secret_credential ARN or name
#
# Optional env var (dev/test only):
#   SECRET_KEY_BASE_PREVIOUS  - JSON array or single string of previous keys

require_relative "../../lib/jit/security/secret_key_base_provider"

Rails.application.config.before_initialize do |app|
  provider = Jit::Security::SecretKeyBaseProvider
  keys = provider.fetch

  if keys[:current].present?
    app.config.secret_key_base = keys[:current]
  end

  keys[:previous].each do |old_key|
    app.message_verifiers.rotate(secret_key_base: old_key)
  end
end
