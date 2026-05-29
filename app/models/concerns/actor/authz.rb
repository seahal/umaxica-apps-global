# typed: false
# frozen_string_literal: true

class Actor
  Authz =
    Data.define(:policy_user, :token_claims, :surface) do
      def self.null = self::NULL

      def null?
        policy_user.blank? && token_claims.blank? && surface.blank?
      end
    end

  Actor::Authz::NULL = Actor::Authz.new(policy_user: nil, token_claims: nil, surface: nil).freeze
end
