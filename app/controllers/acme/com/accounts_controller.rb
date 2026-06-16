# typed: false
# frozen_string_literal: true

module Acme
  module Com
    class AccountsController < Acme::Com::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_visitor!

      def index = show

      def show
        authorize!(current_visitor, to: :show?)
      end

      def edit
        authorize!(current_visitor, to: :update?)
      end

      def update
        authorize!(current_visitor, to: :update?)
        redirect_to(acme_com_account_path(ri: params[:ri]), status: :see_other)
      end
    end
  end
end
