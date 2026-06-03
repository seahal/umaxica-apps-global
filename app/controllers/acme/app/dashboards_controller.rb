# typed: false
# frozen_string_literal: true

module Acme
  module App
    class DashboardsController < Acme::App::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_client!

      def show
        render "acme/shared/dashboards/show"
      end
    end
  end
end
