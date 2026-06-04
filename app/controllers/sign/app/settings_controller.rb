# typed: false
# frozen_string_literal: true

module Sign
  module App
    class SettingsController < Sign::App::ApplicationController
      include ::Sign::SettingsAuthorityRedirect

      AUTHENTICATION_MODE = :private

      def show
        return redirect_to_acme_settings_authority! unless logged_in?
      end
    end
  end
end
