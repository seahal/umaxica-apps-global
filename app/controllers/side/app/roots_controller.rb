# typed: false
# frozen_string_literal: true

module Side
  module App
    class RootsController < Side::App::ApplicationController
      AUTHENTICATION_MODE = :open
      layout false

      def index
        redirect_to(side_app_dashboard_path(ri: params[:ri])) if logged_in?
      end
    end
  end
end
