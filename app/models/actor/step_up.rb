# typed: false
# frozen_string_literal: true

class Actor
  StepUp =
    Data.define(
      :scope,
      :required_aal,
      :allowed_methods,
      :satisfied,
      :satisfied_at,
      :expires_at,
      :usable_token,
      :method,
      :session_bound,
      :token_bound,
      :purpose,
      :audience,
      :purpose_bound,
      :audience_bound,
    ) do
      def self.null = NULL

      def satisfied? = !!satisfied

      def usable_token? = !!usable_token

      def null?
        scope.blank? && required_aal.blank? && !satisfied? && satisfied_at.blank? && expires_at.blank?
      end
    end

  Actor::StepUp::NULL =
    Actor::StepUp.new(
      scope: nil,
      required_aal: nil,
      allowed_methods: [],
      satisfied: false,
      satisfied_at: nil,
      expires_at: nil,
      usable_token: false,
      method: nil,
      session_bound: false,
      token_bound: false,
      purpose: nil,
      audience: nil,
      purpose_bound: false,
      audience_bound: false,
    ).freeze
end
