# typed: false
# frozen_string_literal: true

module Base
  module App
    # Account entity management for the app surface. Plural CRUD over the accounts the
    # signed-in client may act as; changing the *current* account is the switcher's job, not this
    # controller's. Requires a selected actor context (FullAccessController).
    class AccountsController < Base::App::FullAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_client!

      def index
        authorize!(current_client, to: :show?)
        @accounts = Persona.all
      end

      def show
        @account = find_account!
        authorize!(current_client, to: :show?)
      end

      private

      # Scoped to the principal's available accounts: a foreign or non-existent id raises
      # RecordNotFound (404), which is the authoritative ownership gate for show/edit/update.
      def find_account!
        Persona.find_by!(public_id: params.expect(:id))
      end
    end
  end
end
