# typed: false
# frozen_string_literal: true

module Acme
  module App
    class IdentitiesController < Acme::App::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_client!

      def show
        authorize!(current_client, to: :show?)
        render "acme/shared/self_service/show", locals: { page_title: "Identity" }
      end
    end
  end
end
