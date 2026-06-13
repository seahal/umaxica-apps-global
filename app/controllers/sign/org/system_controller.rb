# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class SystemController < ::Sign::RedirectOnlyController
      AUTHENTICATION_MODE = :open

      def index
        redirect_to_acme_authority!("/system")
      end
    end
  end
end
