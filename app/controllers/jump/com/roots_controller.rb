# typed: false
# frozen_string_literal: true

module Jump
  module Com
    class RootsController < Jump::Com::ApplicationController
      include Jump::ToRedirector

      JUMP_LINK_MODEL = ComJumpLink

      def index
        return if params[:to].blank?

        params[:public_id] = params[:to]
        show
      end
    end
  end
end
