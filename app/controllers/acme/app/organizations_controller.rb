# typed: false
# frozen_string_literal: true

module Acme
  module App
    # Organization entity management for the app surface. Plural CRUD over the organizations the
    # signed-in client has a membership in; changing the *current* organization is the switcher's
    # job. Requires a selected actor context (FullAccessController).
    class OrganizationsController < Acme::App::FullAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_client!

      def index
        authorize!(current_client, to: :show?)
        @organizations = Enterprise.all
      end

      def show
        @organization = find_organization!
        authorize!(current_client, to: :show?)
      end

      private

      # Scoped to the organizations the principal is a member of: a foreign or non-existent id
      # raises RecordNotFound (404), the authoritative membership gate for show/edit/update.
      def find_organization!
        Enterprise.find_by!(public_id: params.expect(:id))
      end
    end
  end
end
