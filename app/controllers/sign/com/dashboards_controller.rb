# typed: false
# frozen_string_literal: true

module Sign
  module Com
    class DashboardsController < ::Sign::Com::ApplicationController
      AUTHENTICATION_MODE = :private

      declare_authentication_mode! :private

      before_action :authenticate_visitor!

      def show
        render "sign/com/dashboards/show"
      end
    end
  end
end
