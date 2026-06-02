# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class SettingsController < Sign::Org::ApplicationController
      AUTHENTICATION_MODE = :private

      before_action :authenticate_operator!

      # Object-level authorization (ActionPolicy): the settings dashboard is account-self; gate
      # owner-self via OperatorPolicy#show?.
      def show
        authorize!(current_operator, to: :show?)
      end
    end
  end
end
