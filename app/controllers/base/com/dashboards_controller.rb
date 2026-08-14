# typed: false
# frozen_string_literal: true

module Base
  module Com
    class DashboardsController < Base::Com::FullAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      def show
        authorize!(current_visitor, to: :show?)
        render "base/shared/dashboards/show"
      end
    end
  end
end
