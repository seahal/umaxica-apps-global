# typed: false
# frozen_string_literal: true

module Base
  module App
    class DashboardsController < Base::App::FullAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      def show
        authorize!(current_client, to: :show?)
        render "base/shared/dashboards/show"
      end
    end
  end
end
