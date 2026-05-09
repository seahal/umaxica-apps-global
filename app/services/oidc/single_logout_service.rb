# typed: false
# frozen_string_literal: true

module Oidc
  class SingleLogoutService
    class << self
      def call(user:)
        MarkRecord.connected_to(role: :writing) do
          now = Time.current
          UserToken.where(user_id: user.id)
            .where(status: "active")
            .find_each do |token|
            token.update!(lapses_at: [token.lapses_at, now].compact.min, status: "revoked", updated_at: now)
          end
        end
      end

      def call_for_staff(staff:)
        TokenRecord.connected_to(role: :writing) do
          now = Time.current
          StaffToken.where(staff_id: staff.id)
            .where(status: "active")
            .find_each do |token|
            token.update!(lapses_at: [token.lapses_at, now].compact.min, status: "revoked", updated_at: now)
          end
        end
      end
    end
  end
end
