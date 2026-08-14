# typed: false
# frozen_string_literal: true

module Base
  module App
    class RootsController < Base::App::ApplicationController
      include ::RegionalRootRedirect

      AUTHENTICATION_MODE = :open
      layout false

      redirect_root_to_regional_host(surface: :app)

      def index
        redirect_to(base_app_dashboard_path(ri: params[:ri])) if logged_in?
      end
    end
  end
end
