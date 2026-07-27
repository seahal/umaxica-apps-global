# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  class LegacyIdentityRepositoryFactory
    def self.build(provider)
      case provider.to_s
      when "apple"
        LegacyIdentityRepositoryAdapter.new(
          provider: "apple",
          model_class: ClientAppleIdentity,
          stored_providers: ["apple"],
        )
      when "google"
        LegacyIdentityRepositoryAdapter.new(
          provider: "google",
          model_class: ClientGoogleIdentity,
          stored_providers: %w(google google_app),
        )
      else
        raise ArgumentError, "provider is unsupported"
      end
    end
  end
end
