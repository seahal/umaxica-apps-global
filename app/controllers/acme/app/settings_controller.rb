# typed: false
# frozen_string_literal: true

module Acme
  module App
    class SettingsController < Acme::App::FullAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_client!

      def show
        authorize!(current_client, to: :show?)
        render "acme/app/settings/show"
      end
    end
  end
end
