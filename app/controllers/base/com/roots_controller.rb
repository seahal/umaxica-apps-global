# typed: false
# frozen_string_literal: true

module Base
  module Com
    class RootsController < Base::Com::ApplicationController
      include ::RegionalRootRedirect

      AUTHENTICATION_MODE = :open
      layout false

      redirect_root_to_regional_host(surface: :com)

      def index
        redirect_to(base_com_dashboard_path(ri: params[:ri])) if logged_in?
      end
    end
  end
end
