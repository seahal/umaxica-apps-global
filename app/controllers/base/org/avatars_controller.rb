# typed: false
# frozen_string_literal: true

module Base
  module Org
    class AvatarsController < Base::Org::FullAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_operator!

      def show
        authorize!(current_operator, to: :show?)
      end

      def edit
        authorize!(current_operator, to: :update?)
      end

      def update
        authorize!(current_operator, to: :update?)
        redirect_to(base_org_avatar_path(ri: params[:ri]), status: :see_other)
      end

      def destroy
        authorize!(current_operator, to: :destroy?)
        redirect_to(base_org_avatar_path(ri: params[:ri]), status: :see_other)
      end
    end
  end
end
