# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  module AppleCredentialRevocationPort
    def call(refresh_token:)
      raise NotImplementedError
    end
  end
end
