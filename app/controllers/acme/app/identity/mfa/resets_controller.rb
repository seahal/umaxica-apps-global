# typed: false
# frozen_string_literal: true

module Acme
  module App
    module Identity
      module Mfa
        class ResetsController < BaseController
          before_action :authenticate_client!
          def show = (authorize!(current_client, to: :show?); render "sign/app/settings/mfa/resets/show")

          def create
            (authorize!(current_client, to: :update?)
             redirect_to(
               acme_app_identity_mfa_reset_path(ri: params[:ri]),
               alert: t("sign.app.settings.mfa.show.reset_unavailable"),
             ))
          end
        end
      end
    end
  end
end
