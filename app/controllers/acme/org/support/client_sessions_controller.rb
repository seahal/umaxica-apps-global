# typed: false
# frozen_string_literal: true

module Acme
  module Org
    module Support
      class ClientSessionsController < Acme::Org::ApplicationController
        include AcmeOrgSupportAccountSessionRevocation

        AUTHENTICATION_MODE = :private
        TARGET_ACCOUNT_CLASS = Client
        TARGET_PARAM = :client_id

        declare_authentication_mode! :private
        before_action :require_session_revoke_step_up!
        before_action :set_target_account
        before_action :authorize_target_account!
      end
    end
  end
end
