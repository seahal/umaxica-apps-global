# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      module Mfa
        class ResetsController < BaseController
          AUTHENTICATION_MODE = :private
          declare_authentication_mode! :private

          before_action :authenticate_client!
          def show = (authorize!(current_client, to: :show?); render "auth/app/settings/mfa/resets/show")

          def create
            (authorize!(current_client, to: :update?)
             redirect_to(
               base_app_identity_mfa_reset_path(ri: params[:ri]),
             ))
          end
        end
      end
    end
  end
end
