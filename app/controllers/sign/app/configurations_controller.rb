# typed: false
# frozen_string_literal: true

module Sign
  module App
    class ConfigurationsController < PrivateController
      before_action :authenticate_client!

      def show
      end

      def edit
        return if current_client.deactivated?

        safe_redirect_to(
          sign_app_configuration_path(ri: params[:ri]),
          fallback: sign_app_configuration_path,
        )
      end
    end
  end
end
