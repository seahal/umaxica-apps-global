# typed: false
# frozen_string_literal: true

module Sign
  module App
    class WelcomesController < Sign::RedirectOnlyController
      def show
        redirect_to_acme_authority!("/welcome")
      end
    end
  end
end
