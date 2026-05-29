# typed: false
# frozen_string_literal: true

module Sign
  module App
    class DashboardsController < Sign::App::ApplicationController
      AUTHENTICATION_MODE = :private

      before_action :authenticate_client!

      def show
      end
    end
  end
end
