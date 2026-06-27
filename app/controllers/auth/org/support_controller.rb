# typed: false
# frozen_string_literal: true

module Auth
  module Org
    class SupportController < ::Auth::RedirectOnlyController
      AUTHENTICATION_MODE = :open

      def index
        redirect_to_acme_authority!("/support")
      end
    end
  end
end
