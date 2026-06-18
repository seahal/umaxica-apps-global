# typed: false
# frozen_string_literal: true

module Acme
  module App
    class SettingsController < Acme::App::FullAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_client!

      def show
        redirect_to(
          sign_app_settings_url(
            ri: params[:ri],
            host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
          ),
          allow_other_host: cross_host_redirect_allowed?,
          status: :see_other,
        )
      end
    end
  end
end
