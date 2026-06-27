# typed: false
# frozen_string_literal: true

module Base
  module Org
    class DashboardsController < Base::Org::FullAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      def show
        render "base/shared/dashboards/show"
      end
    end
  end
end
