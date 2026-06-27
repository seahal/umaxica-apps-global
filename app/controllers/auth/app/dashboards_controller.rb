# typed: false
# frozen_string_literal: true

module Auth
  module App
    class DashboardsController < ::Auth::App::ApplicationController
      AUTHENTICATION_MODE = :private

      declare_authentication_mode! :private

      before_action :authenticate_client!

      def show
        render "auth/app/dashboards/show"
      end
    end
  end
end
