# typed: false
# frozen_string_literal: true

module Sign
  module Com
    class WelcomesController < ::Sign::RedirectOnlyController
      AUTHENTICATION_MODE = :open
      def show
        redirect_to_acme_authority!("/welcome")
      end
    end
  end
end
