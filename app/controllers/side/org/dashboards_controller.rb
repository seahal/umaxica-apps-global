# typed: false
# frozen_string_literal: true

module Side
  module Org
    class DashboardsController < Side::Org::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_operator!

      def show
        authorize!(current_operator, to: :show?)
        render "side/shared/dashboards/show"
      end
    end
  end
end
