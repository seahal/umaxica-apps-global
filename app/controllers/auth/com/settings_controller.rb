# typed: false
# frozen_string_literal: true

module Auth
  module Com
    class SettingsController < ::Auth::Com::ApplicationController
      AUTHENTICATION_MODE = :private

      before_action :authenticate_visitor!

      def show
        authorize!(current_visitor, to: :show?)
        render "auth/com/settings/show"
      end
    end
  end
end
