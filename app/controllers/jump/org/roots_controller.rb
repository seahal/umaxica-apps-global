# typed: false
# frozen_string_literal: true

module Jump
  module Org
    class RootsController < Jump::Org::ApplicationController
      include Jump::ToRedirector

      JUMP_LINK_MODEL = OrgJumpLink

      def index
        return if params[:to].blank?

        params[:public_id] = params[:to]
        show
      end
    end
  end
end
