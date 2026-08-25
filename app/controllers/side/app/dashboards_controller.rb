# typed: false
# frozen_string_literal: true

module Side
  module App
    class DashboardsController < Side::App::ApplicationController
      include ::SideDashboardPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_client!

      def show
        authorize!(current_client, to: :show?)
        render inertia: true, props: dashboard_page_props
      end
    end
  end
end
