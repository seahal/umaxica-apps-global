# typed: false
# frozen_string_literal: true

module Oidc
  class SingleLogoutService
    class << self
      def call(user:)
        MarkRecord.connected_to(role: :writing) do
          UserToken.active_status.where(user_id: user.id).find_each do |token|
            token.revoke!
          end
        end
      end

      def call_for_staff(staff:)
        TokenRecord.connected_to(role: :writing) do
          OperatorToken.active_status.where(staff_id: staff.id).find_each do |token|
            token.revoke!
          end
        end
      end

      def call_for_visitor(visitor:)
        SymbolRecord.connected_to(role: :writing) do
          VisitorToken.active_status.where(visitor_id: visitor.id).find_each do |token|
            token.revoke!
          end
        end
      end
    end
  end
end
