# typed: false
# frozen_string_literal: true

module Jump
  module App
    class RootsController < Jump::App::ApplicationController
      include Jump::ToRedirector

      AUTHENTICATION_MODE = :deny_all

      def index
        return render_not_found if params[:jt].blank?

        show
      end
    end
  end
end
