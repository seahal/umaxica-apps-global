# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Settings
      module Mfa
        class ResetsController < ::Sign::App::ApplicationController
          AUTHENTICATION_MODE = :private

          before_action :authenticate_client!

          # Object-level authorization (ActionPolicy): the MFA-reset surface is account-self; gate
          # owner-self via ClientPolicy#show? (read) / #update? (the reset write, currently disabled).
          def show
            authorize!(current_client, to: :show?)
          end

          def create
            authorize!(current_client, to: :update?)
            redirect_to(
              sign_app_mfa_reset_path(ri: params[:ri]),
              alert: t("sign.app.settings.mfa.show.reset_unavailable"),
            )
          end
        end
      end
    end
  end
end
