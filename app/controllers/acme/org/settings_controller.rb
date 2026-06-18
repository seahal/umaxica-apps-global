# typed: false
# frozen_string_literal: true

module Acme
  module Org
    class SettingsController < Acme::Org::FullAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_operator!

      def show
        redirect_to(
          sign_org_settings_url(
            ri: params[:ri],
            host: ENV.fetch("ID_STAFF_URL", "id.org.localhost"),
          ),
          allow_other_host: cross_host_redirect_allowed?,
          status: :see_other,
        )
      end
    end
  end
end
