# typed: false
# frozen_string_literal: true

module Base
  module Org
    class DashboardsController < Base::Org::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_operator!

      def show
        render "base/shared/dashboards/show"
      end
    end
  end
end
