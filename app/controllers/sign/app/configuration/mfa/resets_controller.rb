# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Configuration
      module Mfa
        class ResetsController < Sign::App::ApplicationController
          AUTHENTICATION_MODE = :private

          before_action :authenticate_client!

          def show
          end

          def create
            redirect_to(
              sign_app_mfa_reset_path(ri: params[:ri]),
              alert: t("sign.app.configuration.mfa.show.reset_unavailable"),
            )
          end
        end
      end
    end
  end
end
