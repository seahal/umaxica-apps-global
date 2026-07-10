# typed: false
# frozen_string_literal: true

module Auth
  module Org
    class DashboardsController < ::Auth::Org::ApplicationController
      AUTHENTICATION_MODE = :private

      declare_authentication_mode! :private

      before_action :authenticate_operator!

      def show
        render "auth/org/dashboards/show"
      end
    end
  end
end
