# typed: false
# frozen_string_literal: true

module Acme
  module Org
    module Support
      class OperatorSessionsController < Acme::Org::ApplicationController
        include AcmeOrgSupportAccountSessionRevocation

        AUTHENTICATION_MODE = :private
        TARGET_ACCOUNT_CLASS = Operator
        TARGET_PARAM = :operator_id
      end
    end
  end
end
