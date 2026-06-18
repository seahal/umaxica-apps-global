# typed: false
# frozen_string_literal: true

module Sign
  module App
    class SettingsController < ::Sign::App::ApplicationController
      AUTHENTICATION_MODE = :private

      before_action :authenticate_client!

      def show
        authorize!(current_client, to: :show?)
        render "sign/app/settings/show"
      end
    end
  end
end
