# typed: false
# frozen_string_literal: true

module Sign
  module Com
    class SettingsController < ::Sign::Com::ApplicationController
      AUTHENTICATION_MODE = :private

      before_action :authenticate_visitor!

      def show
        authorize!(current_visitor, to: :show?)
        render "sign/com/settings/show"
      end
    end
  end
end
