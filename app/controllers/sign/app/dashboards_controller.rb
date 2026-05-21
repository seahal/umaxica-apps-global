# typed: false
# frozen_string_literal: true

module Sign
  module App
    class DashboardsController < PrivateController
      before_action :authenticate_client!

      def show
      end
    end
  end
end
