# typed: false
# frozen_string_literal: true

module Jump
  module App
    class RootsController < Jump::PublicController
      include Jump::ToRedirector

      JUMP_LINK_MODEL = AppJumpLink

      def index
        if params[:to].present?
          params[:public_id] = params[:to]
          return show
        end

        render_not_found
      end
    end
  end
end
