# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class SupportController < ::Sign::RedirectOnlyController
      AUTHENTICATION_MODE = :open

      def index
        redirect_to_acme_authority!("/support")
      end
    end
  end
end
