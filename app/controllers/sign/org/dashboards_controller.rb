# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class DashboardsController < Sign::Org::ApplicationController
      AUTHENTICATION_MODE = :private

      before_action :authenticate_operator!

      def show
      end
    end
  end
end
