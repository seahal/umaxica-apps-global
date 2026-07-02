# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      module Revocations
        class AllsController < BaseController
          AUTHENTICATION_MODE = :private
          declare_authentication_mode! :private

          before_action :authenticate_client!
          def create
            AuthenticationSessionRevoker.revoke_all_for(current_client)
            redirect_to(base_app_sign_out_path(ri: params[:ri]), status: :see_other)
          end
          alias_method :destroy, :create
        end
      end
    end
  end
end
