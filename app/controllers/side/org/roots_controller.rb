# typed: false
# frozen_string_literal: true

module Side
  module Org
    class RootsController < Side::Org::ApplicationController
      AUTHENTICATION_MODE = :open
      layout false

      def index
        redirect_to(side_org_dashboard_path(ri: params[:ri])) if logged_in?
      end
    end
  end
end
