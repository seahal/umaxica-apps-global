# typed: false
# frozen_string_literal: true

module Sign
  module Com
    class DashboardsController < Sign::Com::ApplicationController
      AUTHENTICATION_MODE = :private

      before_action :authenticate_visitor!

      def show
      end
    end
  end
end
