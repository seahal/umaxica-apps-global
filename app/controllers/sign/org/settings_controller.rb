# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class SettingsController < ::Sign::Org::ApplicationController
      AUTHENTICATION_MODE = :private

      before_action :authenticate_operator!

      def show
        authorize!(current_operator, to: :show?)
        render "sign/org/settings/show"
      end
    end
  end
end
