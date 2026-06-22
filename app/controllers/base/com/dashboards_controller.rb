# typed: false
# frozen_string_literal: true

module Base
  module Com
    class DashboardsController < Base::Com::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_visitor!

      def show
        render "base/shared/dashboards/show"
      end
    end
  end
end
