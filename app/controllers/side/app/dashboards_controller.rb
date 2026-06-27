# typed: false
# frozen_string_literal: true

module Side
  module App
    class DashboardsController < Side::App::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_client!

      def show
        render "side/shared/dashboards/show"
      end
    end
  end
end
