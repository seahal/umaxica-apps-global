# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Identity
      class RotationsController < ::Base::Org::ApplicationController
        AUTHENTICATION_MODE = :private
        before_action :authenticate_operator!

        def create
          secret = current_operator.staff_secret_credentials.find_by!(public_id: params.expect(:secret_id))
          redirect_to edit_base_org_identity_secret_path(secret.public_id, ri: params[:ri]), status: :see_other
        end
      end
    end
  end
end
