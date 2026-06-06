# typed: false
# frozen_string_literal: true

module Acme
  module Com
    class DashboardsController < Acme::Com::FullAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      def show
        render "acme/shared/dashboards/show"
      end
    end
  end
end
