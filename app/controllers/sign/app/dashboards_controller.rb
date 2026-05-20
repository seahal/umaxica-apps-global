# typed: false
# frozen_string_literal: true

module Sign
  module App
    class DashboardsController < PrivateController
      before_action :authenticate_client!
      before_action :continue_dashboard_sequence_without_content!

      def show
      end
    end
  end
end
