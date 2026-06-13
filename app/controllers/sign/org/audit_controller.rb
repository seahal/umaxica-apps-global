# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class AuditController < ::Sign::RedirectOnlyController
      AUTHENTICATION_MODE = :open

      def index
        redirect_to_acme_authority!("/audit")
      end
    end
  end
end
