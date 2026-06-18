# typed: false
# frozen_string_literal: true

module Sign
  module App
    class DashboardsController < ::Sign::App::ApplicationController
      AUTHENTICATION_MODE = :private

      declare_authentication_mode! :private

      before_action :authenticate_client!

      def show
        render "sign/app/dashboards/show"
      end
    end
  end
end
