# typed: false
# frozen_string_literal: true

module Acme
  module Org
    class AccountsController < Acme::Org::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_operator!

      def index = show

      def show
        authorize!(current_operator, to: :show?)
      end

      def edit
        authorize!(current_operator, to: :update?)
      end

      def update
        authorize!(current_operator, to: :update?)
        redirect_to(acme_org_account_path(ri: params[:ri]), status: :see_other)
      end
    end
  end
end
