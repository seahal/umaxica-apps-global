# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Support
      module Operators
        class SessionsController < Base::Org::ApplicationController
          include BaseOrgSupportAccountSessionRevocation

          AUTHENTICATION_MODE = :private
          TARGET_ACCOUNT_CLASS = Operator
          TARGET_PARAM = :operator_id

          declare_authentication_mode! :private
          before_action :require_session_revoke_step_up!
          before_action :set_target_account
          before_action :authorize_target_account!
        end
      end
    end
  end
end
