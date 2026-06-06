# typed: false
# frozen_string_literal: true

module Acme
  module Com
    class SelectorsController < Acme::Com::PreAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      def show
        Acme::Selector::BootstrapAuthority.call(surface: :com, principal: current_visitor)
        render json: Acme::Selector::Authority.prepare(surface: :com, principal: current_visitor, session: current_session)
      end

      def update
        render json: Acme::Selector::Authority.select(
          surface: :com,
          principal: current_visitor,
          session: current_session,
          params: selector_params,
        )
      rescue Acme::Selector::Authority::InvalidSelection => e
        render json: { status: "invalid_selection", error: e.message }, status: :unprocessable_entity
      end

      private

      def selector_params
        params.permit(:account_public_id, :organization_public_id, :organization_unit_public_id,
                      :collective_public_id, :collective_unit_public_id).to_h.symbolize_keys
      end
    end
  end
end
