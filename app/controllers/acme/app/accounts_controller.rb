# typed: false
# frozen_string_literal: true

module Acme
  module App
    class AccountsController < Acme::App::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_client!

      def index = show

      def show
        authorize!(current_client, to: :show?)
      end

      def edit
        authorize!(current_client, to: :update?)
      end

      def update
        authorize!(current_client, to: :update?)
        redirect_to(acme_app_account_path(ri: params[:ri]), status: :see_other)
      end
    end
  end
end
