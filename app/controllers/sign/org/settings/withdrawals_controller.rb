# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Settings
      class WithdrawalsController < Sign::Org::ApplicationController
        AUTHENTICATION_MODE = :private

        def show
          redirect_to_acme_withdrawal! unless step_up_satisfied?(scope: "withdrawal")
        end

        private

        def redirect_to_acme_withdrawal!
          redirect_to(
            URI::Generic.build(
              scheme: request.scheme,
              host: ENV.fetch("ACME_STAFF_URL", "www.org.localhost"),
              path: "/settings/withdrawal",
              query: { ri: params[:ri] }.compact.to_query,
            ).to_s,
            allow_other_host: cross_host_redirect_allowed?,
            status: :see_other,
          )
        end
      end
    end
  end
end
