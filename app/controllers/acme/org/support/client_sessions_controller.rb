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
      end
    end
  end
end
