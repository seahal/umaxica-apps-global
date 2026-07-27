# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  class ProviderSurfacePolicy
    ALLOWED_OPERATIONS = {
      "app" => {
        "apple" => %w(link login signup).freeze,
        "google" => %w(link login signup).freeze,
      }.freeze,
      "org" => {
        "entra" => %w(login).freeze,
      }.freeze,
      "com" => {}.freeze,
    }.freeze

    def allowed?(surface:, provider:, operation:)
      ALLOWED_OPERATIONS.fetch(surface, {}).fetch(provider, []).include?(operation)
    end
  end
end
