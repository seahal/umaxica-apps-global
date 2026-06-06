# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class DashboardsController < ::Sign::RedirectOnlyController
      AUTHENTICATION_MODE = :private
      def show
        redirect_to_acme_authority!("/dashboard")
      end
    end
  end
end
