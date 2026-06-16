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
        end

        def edit
          authorize!(current_client, to: :update?)
        end

        def update
          authorize!(current_client, to: :update?)
          redirect_to(acme_app_avatar_path(ri: params[:ri]), status: :see_other)
        end

        def destroy
          authorize!(current_client, to: :destroy?)
          redirect_to(acme_app_avatar_path(ri: params[:ri]), status: :see_other)
        end
      end
    end
  end
end
