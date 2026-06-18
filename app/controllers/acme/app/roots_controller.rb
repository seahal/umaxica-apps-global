# typed: false
# frozen_string_literal: true

module Acme
  module App
    class RootsController < Acme::App::ApplicationController
      AUTHENTICATION_MODE = :open
      layout false

      def index
        redirect_to(acme_app_dashboard_path(ri: params[:ri])) if logged_in?
      end
    end
  end
end
