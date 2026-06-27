# typed: false
# frozen_string_literal: true

module Auth
  module Org
    class IamController < ::Auth::RedirectOnlyController
      AUTHENTICATION_MODE = :open

      def index
        redirect_to_acme_authority!("/iam")
      end
    end
  end
end
