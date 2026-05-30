# typed: false
# frozen_string_literal: true

module Sign
  module Com
    class ConfigurationsController < Sign::Com::ApplicationController
      AUTHENTICATION_MODE = :private

      before_action :authenticate_visitor! # FIXME: I don't think this is needed

      # Object-level authorization (ActionPolicy): the settings dashboard is account-self; gate
      # owner-self via VisitorPolicy#show?.
      def show
        authorize!(current_visitor, to: :show?)
      end
    end
  end
end
