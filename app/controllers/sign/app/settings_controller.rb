# typed: false
# frozen_string_literal: true

module Sign
  module App
    class SettingsController < Sign::App::ApplicationController
      AUTHENTICATION_MODE = :private

      before_action :authenticate_client! # FIXME: I don't think this is needed

      # Object-level authorization (ActionPolicy): the settings dashboard is account-self; gate
      # owner-self via ClientPolicy#show?.
      def show
        authorize!(current_client, to: :show?)
      end
    end
  end
end
