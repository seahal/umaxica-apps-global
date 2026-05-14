# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class DashboardsController < ApplicationController
      auth_required!
      before_action :authenticate_operator!
      before_action :continue_dashboard_sequence_without_content!

      def show
      end
    end
  end
end
