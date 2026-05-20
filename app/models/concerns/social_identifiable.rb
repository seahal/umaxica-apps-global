# typed: false
# frozen_string_literal: true

# Shared concern for social identity models (ClientSocialGoogle, ClientSocialApple, etc.)
# Provides common methods for OAuth identity management.
module SocialIdentifiable
  extend ActiveSupport::Concern

  PROVIDER_MAP = {
    "google_app" => "google",
    "google_org" => "google",
    "apple" => "apple",
    "microsoft_graph" => "microsoft",
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
      when "google_app", "google_org", "google"
        ClientSocialGoogle
      when "apple"
        ClientSocialApple
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
end
