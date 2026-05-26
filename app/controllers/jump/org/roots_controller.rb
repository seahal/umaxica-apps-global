# typed: false
# frozen_string_literal: true

module Jump
  module Org
    class RootsController < Jump::Org::ApplicationController
      include Jump::ToRedirector

      AUTHENTICATION_MODE = :deny_all

      JUMP_LINK_MODEL = OrgJumpLink

      def index
        return if params[:to].blank? && params[:jt].blank?

        params[:public_id] = params[:to]
        show
      end
    end
  end
end
