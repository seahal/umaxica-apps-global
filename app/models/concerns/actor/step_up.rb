# typed: false
# frozen_string_literal: true

class Actor
  StepUp =
    Data.define(:scope, :required_aal, :satisfied, :satisfied_at, :expires_at, :usable_token) do
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
      satisfied: false,
      satisfied_at: nil,
      expires_at: nil,
      usable_token: false,
    ).freeze
end
