# typed: false
# frozen_string_literal: true

module Sign
  module App
    class SettingsController < ::Sign::App::ApplicationController
      AUTHENTICATION_MODE = :private

      before_action :authenticate_client!

      def show
        authorize!(current_client, to: :show?)
        redirect_to(acme_app_identity_url(ri: params[:ri]), status: :see_other)
      end
    end
  end
end
