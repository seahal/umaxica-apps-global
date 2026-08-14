# typed: false
# frozen_string_literal: true

module Auth
  module Com
    class DashboardsController < ::Auth::Com::ApplicationController
      AUTHENTICATION_MODE = :private

      declare_authentication_mode! :private

      before_action :authenticate_visitor!

      def show
        authorize!(current_visitor, to: :show?)
        render "auth/com/dashboards/show"
      end
    end
  end
end
