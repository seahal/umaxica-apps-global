# typed: false
# frozen_string_literal: true

module Base
  module Org
    class SelectorsController < Base::Org::PreAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      def show
        authorize!(current_operator, to: :show?)
        BaseSelectorBootstrapAuthority.call(surface: :org, principal: current_operator)
        render json: BaseSelectorAuthority.prepare(
          surface: :org, principal: current_operator,
          session: current_session,
        )
      end

      def update
        authorize!(current_operator, to: :update?)
        render json: BaseSelectorAuthority.select(
          surface: :org,
          principal: current_operator,
          session: current_session,
          params: selector_params,
        )
      rescue BaseSelectorAuthority::InvalidSelection => e
        render json: { status: "invalid_selection", error: e.message }, status: :unprocessable_content
      end

      private

      def selector_params
        params.permit(
          :account_public_id, :organization_public_id, :organization_unit_public_id,
          :collective_public_id, :collective_unit_public_id,
        ).to_h.symbolize_keys
      end
    end
  end
end
