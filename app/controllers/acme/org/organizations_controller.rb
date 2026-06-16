# typed: false
# frozen_string_literal: true

module Acme
  module Org
    class OrganizationsController < Acme::Org::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_operator!

      def index
      end

      def show
        authorize!(current_operator, to: :show?)
      end

      def new
      end

      def edit
      end

      def create
        redirect_to(acme_org_organizations_path(ri: params[:ri]), status: :see_other)
      end

      def update
        redirect_to(acme_org_organization_path(ri: params[:ri]), status: :see_other)
      end
    end
  end
end
