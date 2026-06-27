# typed: false
# frozen_string_literal: true

module Base
  module Com
    class SelectorsController < Base::Com::PreAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      def show
        BaseSelectorBootstrapAuthority.call(surface: :com, principal: current_visitor)
        render json: BaseSelectorAuthority.prepare(
          surface: :com, principal: current_visitor,
          session: current_session,
        )
      end

      def update
        render json: BaseSelectorAuthority.select(
          surface: :com,
          principal: current_visitor,
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
