# typed: false
# frozen_string_literal: true

module SocialIdentifiable
  module_function

  def normalize_provider(provider)
    normalized = provider.to_s.downcase
    return "google" if %w(google_app google_oauth2).include?(normalized)

    normalized
  end
end
