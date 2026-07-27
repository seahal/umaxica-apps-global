# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  class AppleCredentialCandidate
    attr_reader :refresh_token

    def initialize(refresh_token:)
      unless refresh_token.is_a?(String) && refresh_token.present?
        raise ArgumentError, "refresh_token is required"
      end

      @refresh_token = refresh_token.dup.freeze
      freeze
    end

    def inspect
      "#<#{self.class.name} refresh_token=[FILTERED]>"
    end

    alias to_s inspect

    def as_json(*)
      raise TypeError, "Apple credential candidates cannot be serialized"
    end
  end
end
