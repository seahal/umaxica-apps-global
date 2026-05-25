# typed: false
# frozen_string_literal: true

module StepUp
  class Resolver
    DEFAULT_TTL = 15.minutes
    DEFAULT_REQUIRED_AAL = :aal2

    def self.call(token:, scope:, required_aal: DEFAULT_REQUIRED_AAL, now: Time.current, ttl: DEFAULT_TTL)
      new(token: token, scope: scope, required_aal: required_aal, now: now, ttl: ttl).call
    end

    def initialize(token:, scope:, required_aal:, now:, ttl:)
      @token = token
      @scope = scope
      @required_aal = required_aal
      @now = now
      @ttl = ttl
    end

    def call
      Actor::StepUp.new(
        scope: scope,
        required_aal: required_aal,
        satisfied: satisfied?,
        satisfied_at: satisfied_at,
        expires_at: expires_at,
        usable_token: usable_token?,
      )
    end

    private

    attr_reader :token, :scope, :required_aal, :now, :ttl

    def satisfied?
      usable_token? &&
        satisfied_at.present? &&
        expires_at.present? &&
        expires_at > now &&
        scope_matches?
    end

    def usable_token?
      token.present? && token.currently_usable?
    end

    def satisfied_at
      token&.last_step_up_at
    end

    def expires_at
      satisfied_at + ttl if satisfied_at.present?
    end

    def scope_matches?
      scope.blank? || token.last_step_up_scope == scope
    end
  end
end
