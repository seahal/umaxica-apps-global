# typed: false
# frozen_string_literal: true

module Acme
  module Org
    class SelectorsController < Acme::Org::PreAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      def show
        Acme::Selector::BootstrapAuthority.call(surface: :org, principal: current_operator)
        render json: Acme::Selector::Authority.prepare(
          surface: :org, principal: current_operator,
          session: current_session,
        )
      end

      def update
        render json: Acme::Selector::Authority.select(
          surface: :org,
          principal: current_operator,
          session: current_session,
          params: selector_params,
        )
      rescue Acme::Selector::Authority::InvalidSelection => e
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
