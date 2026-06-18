# typed: false
# frozen_string_literal: true

module Acme
  module Org
    class RootsController < Acme::Org::ApplicationController
      AUTHENTICATION_MODE = :open
      layout false

      def index
        redirect_to(acme_org_dashboard_path(ri: params[:ri])) if logged_in?
      end
    end
  end
end
