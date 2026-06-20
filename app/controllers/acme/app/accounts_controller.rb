# typed: false
# frozen_string_literal: true

module Acme
  module App
    # Account (Persona) entity management for the app surface. Plural CRUD over the accounts the
    # signed-in client may act as; changing the *current* account is the switcher's job, not this
    # controller's. Requires a selected actor context (FullAccessController).
    class AccountsController < Acme::App::FullAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_client!

      def index
        authorize!(current_client, to: :show?)
        @accounts = switcher.available_accounts
      end

      def show
        @account = find_account!
        authorize!(current_client, to: :show?)
      end

      def new
        authorize!(current_client, to: :update?)
      end

      def edit
        @account = find_account!
        authorize!(current_client, to: :update?)
      end

      def create
        authorize!(current_client, to: :update?)
        redirect_to(acme_app_accounts_path(ri: params[:ri]), status: :see_other)
      end

      def update
        @account = find_account!
        authorize!(current_client, to: :update?)
        redirect_to(acme_app_account_path(@account.public_id, ri: params[:ri]), status: :see_other)
      end

      private

      # Scoped to the principal's available accounts: a foreign or non-existent id raises
      # RecordNotFound (404), which is the authoritative ownership gate for show/edit/update.
      def find_account!
        switcher.find_account(params[:id]) || raise(ActiveRecord::RecordNotFound)
      end

      def switcher
        @switcher ||= AcmeSwitcherAuthority.new(
          surface: :app, principal: current_client, session: current_session,
        )
      end
    end
  end
end
