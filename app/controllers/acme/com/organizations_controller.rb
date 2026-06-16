# typed: false
# frozen_string_literal: true

module Acme
  module Com
    class OrganizationsController < Acme::Com::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_visitor!

      def index
      end

      def show
        authorize!(current_visitor, to: :show?)
      end

      def new
      end

      def edit
      end

      def create
        redirect_to(acme_com_organizations_path(ri: params[:ri]), status: :see_other)
      end

      def update
        redirect_to(acme_com_organization_path(ri: params[:ri]), status: :see_other)
      end
    end
  end
end
