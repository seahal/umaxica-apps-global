# typed: false
# frozen_string_literal: true

module Acme
  module App
    class OrganizationsController < Acme::App::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_client!

      def index
        render "acme/shared/self_service/show", locals: { page_title: "Organizations" }
      end

      def show
        authorize!(current_client, to: :show?)
        render "acme/shared/self_service/show", locals: { page_title: "Organization" }
      end

      def new
        render "acme/shared/self_service/show", locals: { page_title: "New Organization" }
      end

      def create
        render "acme/shared/self_service/show", locals: { page_title: "Organization" }, status: :unprocessable_content
      end

      def edit
        render "acme/shared/self_service/show", locals: { page_title: "Organization" }
      end

      def update
        render "acme/shared/self_service/show", locals: { page_title: "Organization" }
      end
    end
  end
end
