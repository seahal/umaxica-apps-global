# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class DashboardsController < ::Sign::Org::ApplicationController
      AUTHENTICATION_MODE = :private

      declare_authentication_mode! :private

      before_action :authenticate_operator!

      def show
        render "sign/org/dashboards/show"
      end
    end
  end
end
