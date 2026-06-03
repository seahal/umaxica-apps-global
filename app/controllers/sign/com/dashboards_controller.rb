# typed: false
# frozen_string_literal: true

module Sign
  module Com
    class DashboardsController < Sign::RedirectOnlyController
      def show
        redirect_to_acme_authority!("/dashboard")
      end
    end
  end
end
