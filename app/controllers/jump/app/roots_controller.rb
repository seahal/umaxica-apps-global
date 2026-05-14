# typed: false
# frozen_string_literal: true

module Jump
  module App
    class RootsController < Jump::App::ApplicationController
      include Jump::ToRedirector

      JUMP_LINK_MODEL = AppJumpLink

      def index
        return if params[:to].blank?

        params[:public_id] = params[:to]
        show
      end
    end
  end
end
