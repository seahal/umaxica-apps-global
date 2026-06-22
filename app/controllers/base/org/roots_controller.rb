# typed: false
# frozen_string_literal: true

module Base
  module Org
    class RootsController < Base::Org::ApplicationController
      AUTHENTICATION_MODE = :open
      layout false

      def index
        redirect_to(base_org_dashboard_path(ri: params[:ri])) if logged_in?
      end
    end
  end
end
