# typed: false
# frozen_string_literal: true

module Jump
  module Com
    class RootsController < Jump::PublicController
      include Jump::ToRedirector

      JUMP_LINK_MODEL = ComJumpLink

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
