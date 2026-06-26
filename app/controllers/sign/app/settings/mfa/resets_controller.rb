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
          def show = redirect_to(acme_app_identity_mfa_reset_path(ri: params[:ri]), status: :see_other)

          def create = head(:gone)
        end
      end
    end
  end
end
