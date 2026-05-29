# typed: false
# frozen_string_literal: true

module Jump
  module Com
    class RootsController < Jump::Com::ApplicationController
      include Jump::ToRedirector

      AUTHENTICATION_MODE = :deny_all

      def index
        return render_not_found if params[:jt].blank?

        show
      end
    end
  end
end
