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
        @organizations = switcher.available_organizations
      end

      def show
        @organization = find_organization!
        authorize!(current_client, to: :show?)
      end

      def new
        authorize!(current_client, to: :update?)
      end

      def edit
        @organization = find_organization!
        authorize!(current_client, to: :update?)
      end

      def create
        authorize!(current_client, to: :update?)
        redirect_to(acme_app_organizations_path(ri: params[:ri]), status: :see_other)
      end

      def update
        @organization = find_organization!
        authorize!(current_client, to: :update?)
        redirect_to(acme_app_organization_path(@organization.public_id, ri: params[:ri]), status: :see_other)
      end

      private

      # Scoped to the organizations the principal is a member of: a foreign or non-existent id
      # raises RecordNotFound (404), the authoritative membership gate for show/edit/update.
      def find_organization!
        switcher.find_organization(params[:id]) || raise(ActiveRecord::RecordNotFound)
      end

      def switcher
        @switcher ||= AcmeSwitcherAuthority.new(
          surface: :app, principal: current_client, session: current_session,
        )
      end
    end
  end
end
