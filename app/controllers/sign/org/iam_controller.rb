# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class IamController < ::Sign::RedirectOnlyController
      AUTHENTICATION_MODE = :open

      def index
        redirect_to_acme_authority!("/iam")
      end
    end
  end
end
