# typed: false
# frozen_string_literal: true

module Acme
  module App
    module Identity
      module Revocations
        class AllsController < BaseController
          before_action :authenticate_client!
          def create
            AuthenticationSessionRevoker.revoke_all_for(current_client)
            redirect_to(acme_app_sign_out_path(ri: params[:ri]), status: :see_other)
          end
        end
      end
    end
  end
end
