# typed: false
# frozen_string_literal: true

module Base
  module App
    class DashboardsController < Base::App::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_client!

      def show
        render "base/shared/dashboards/show"
      end
    end
  end
end
