# typed: false
# frozen_string_literal: true

module Side
  module Org
    class DashboardsController < Side::Org::ApplicationController
      include ::SideDashboardPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_operator!

      def show
        authorize!(current_operator, to: :show?)
        render inertia: true, props: dashboard_page_props
      end
    end
  end
end
