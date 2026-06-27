# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Settings
      module Mfa
        class ResetsController < ::Auth::App::ApplicationController
          AUTHENTICATION_MODE = :private

          before_action :authenticate_client!

          # Object-level authorization (ActionPolicy): the MFA-reset surface is account-self; gate
          # owner-self via ClientPolicy#show? (read) / #update? (the reset write, currently disabled).
          def show
            render :show
          end

          def create
            redirect_to(
              auth_app_settings_mfa_reset_url(ri: params[:ri]),
              alert: I18n.t("sign.app.settings.mfa.show.reset_unavailable"),
            )
          end
        end
      end
    end
  end
end
