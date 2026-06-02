# typed: false
# frozen_string_literal: true

# Shared concern for social identity models.
# Provides common methods for OAuth identity management.
module SocialIdentifiable
  extend ActiveSupport::Concern

  PROVIDER_MAP = {
    "google_app" => "google",
    "apple" => "apple",
  }.freeze

  included do
    scope :active, -> { where(status_column => status_class::ACTIVE) }
  end

  # Module-level utility methods
  class << self
    def normalize_provider(omniauth_provider)
      PROVIDER_MAP[omniauth_provider.to_s] || omniauth_provider.to_s.downcase
    end

    def model_for_provider(provider)
      case provider.to_s
      when "google_app", "google"
        ClientGoogleIdentity
      when "apple"
        ClientAppleIdentity
      else
        raise ArgumentError, "Unknown provider: #{provider}"
      end
    end
  end

  class_methods do
    # Normalize OmniAuth provider name to internal name
    delegate :normalize_provider, to: :SocialIdentifiable

    # Get the model class for a given provider
    delegate :model_for_provider, to: :SocialIdentifiable

    # Find identity by provider and uid with optional lock
    def find_by_uid_with_lock(uid, lock: false)
      scope = where(uid: uid)
      scope = scope.lock("FOR UPDATE") if lock
      scope.first
    end

    def find_or_create_from_auth_hash(auth)
      identity = find_or_initialize_by(uid: extract_uid(auth), provider: provider_from_auth(auth))
      identity.assign_auth_credentials(auth)
      identity
    end

    def extract_uid(auth)
      auth_value(auth, :uid).to_s
    end

    def provider_from_auth(auth)
      auth_value(auth, :provider).to_s
    end

    def credentials_from_auth(auth)
      credentials = auth_value(auth, :credentials)
      Struct.new(:token, :refresh_token, :expires_at, keyword_init: true).new(
        token: auth_value(credentials, :token),
        refresh_token: auth_value(credentials, :refresh_token),
        expires_at: auth_value(credentials, :expires_at),
      )
    end

    def auth_value(source, key)
      return nil unless source
      return source.public_send(key) if source.respond_to?(key)
      return source[key] || source[key.to_s] if source.respond_to?(:[])

      nil
    rescue KeyError
      nil
    end

    # Status column name (differs per model)
    def status_column
      raise NotImplementedError, "Subclass must define status_column"
    end

    def status_class
      raise NotImplementedError, "Subclass must define status_class"
    end
  end

  # Update last_authenticated_at timestamp
  def touch_authenticated!
    update!(last_authenticated_at: Time.current)
  end

  # Check if this identity is active
  def active?
    public_send(self.class.status_column) == self.class.status_class::ACTIVE
  end

  # Normalized provider name
  def normalized_provider
    self.class.normalize_provider(provider)
  end

  def assign_auth_credentials(auth)
    credentials = self.class.credentials_from_auth(auth)
    self.token = credentials.token
    self.refresh_token = credentials.refresh_token if credentials.refresh_token.present?
    self.token_expires_at = credentials.expires_at
  end

  def update_from_auth_hash!(auth)
    assign_auth_credentials(auth)
    self.last_authenticated_at = Time.current
    save!
  end
end
