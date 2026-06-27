# typed: false
# frozen_string_literal: true

module Auth
  module Org
    class SettingsController < ::Auth::Org::ApplicationController
      AUTHENTICATION_MODE = :private

      before_action :authenticate_operator!

      def show
        authorize!(current_operator, to: :show?)
        render "auth/org/settings/show"
      end
    end
  end
end
