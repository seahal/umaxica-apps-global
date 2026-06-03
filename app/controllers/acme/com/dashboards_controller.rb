# typed: false
# frozen_string_literal: true

module Acme
  module Com
    class DashboardsController < Acme::Com::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_visitor!

      def show
        render "acme/shared/dashboards/show"
      end
    end
  end
end
