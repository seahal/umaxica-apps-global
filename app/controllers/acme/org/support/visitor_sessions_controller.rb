# typed: false
# frozen_string_literal: true

module Acme
  module Org
    module Support
      class VisitorSessionsController < Acme::Org::ApplicationController
        include AcmeOrgSupportAccountSessionRevocation

        AUTHENTICATION_MODE = :private
        TARGET_ACCOUNT_CLASS = Visitor
        TARGET_PARAM = :visitor_id
      end
    end
  end
end
