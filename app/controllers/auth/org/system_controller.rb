# typed: false
# frozen_string_literal: true

module Auth
  module Org
    class SystemController < ::Auth::RedirectOnlyController
      AUTHENTICATION_MODE = :open

      def index
        redirect_to_acme_authority!("/system")
      end
    end
  end
end
