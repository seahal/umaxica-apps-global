# typed: false
# frozen_string_literal: true

module Acme
  module App
    class OrganizationsController < Acme::App::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_client!

      def index
      end

      def show
        authorize!(current_client, to: :show?)
      end

      def new
      end

      def edit
      end

      def create
        redirect_to(acme_app_organizations_path(ri: params[:ri]), status: :see_other)
      end

      def update
        redirect_to(acme_app_organization_path(ri: params[:ri]), status: :see_other)
      end
    end
  end
end
