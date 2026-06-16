# typed: false
# frozen_string_literal: true

module Acme
  module App
    module Current
      class AvatarsController < Acme::App::ApplicationController
        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_client!

        def show
          authorize!(current_client, to: :show?)
          render "acme/shared/self_service/show", locals: { page_title: "Avatar" }
        end

        def edit
          authorize!(current_client, to: :update?)
          render "acme/shared/self_service/show", locals: { page_title: "Avatar" }
        end

        def update
          authorize!(current_client, to: :update?)
          render "acme/shared/self_service/show", locals: { page_title: "Avatar" }
        end

        def destroy
          authorize!(current_client, to: :destroy?)
          head :no_content
        end
      end
    end
  end
end
