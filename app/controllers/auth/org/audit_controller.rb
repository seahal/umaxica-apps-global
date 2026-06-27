# typed: false
# frozen_string_literal: true

module Auth
  module Org
    class AuditController < ::Auth::RedirectOnlyController
      AUTHENTICATION_MODE = :open

      def index
        redirect_to_acme_authority!("/audit")
      end
    end
  end
end
