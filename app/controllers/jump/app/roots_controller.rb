# typed: false
# frozen_string_literal: true

module Jump
  module App
    class RootsController < Jump::App::ApplicationController
      include Jump::ToRedirector

      AUTHENTICATION_MODE = :deny_all

      JUMP_LINK_MODEL = AppJumpLink

      def index
        return if params[:to].blank? && params[:jt].blank?

        params[:public_id] = params[:to]
        show
      end
    end
  end
end
