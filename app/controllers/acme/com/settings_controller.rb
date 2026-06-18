# typed: false
# frozen_string_literal: true

module Acme
  module Com
    class SettingsController < Acme::Com::FullAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_visitor!

      def show
        redirect_to(
          sign_com_settings_url(
            ri: params[:ri],
            host: ENV.fetch("ID_CORPORATE_URL", "id.com.localhost"),
          ),
          allow_other_host: cross_host_redirect_allowed?,
          status: :see_other,
        )
      end
    end
  end
end
