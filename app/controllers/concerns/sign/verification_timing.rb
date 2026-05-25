# typed: false
# frozen_string_literal: true

module Sign
  module VerificationTiming
    extend ActiveSupport::Concern

    VERIFICATION_GET_TTL = 15.minutes
    VERIFICATION_POST_TTL = 30.minutes

    private

    def verification_recent_for_get?(scope: nil)
      verification_recent?(scope: scope, ttl: VERIFICATION_GET_TTL)
    end

    def verification_recent_for_post?(scope: nil)
      verification_recent?(scope: scope, ttl: VERIFICATION_POST_TTL)
    end

    def verification_recent?(scope:, ttl:)
      StepUp::Resolver.call(token: actor_token_for_verification, scope: scope, ttl: ttl).satisfied?
    end

    def actor_token_for_verification
      return actor_token if respond_to?(:actor_token)

      instance_variable_get(:@actor_token)
    end
  end
end
