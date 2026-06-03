# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Settings
      class WithdrawalsController < Sign::RedirectOnlyController
        def show = redirect_to_acme_withdrawal!

        private

        # sign/id is redirect-only here. acme/www owns withdrawal mutation.
        def redirect_to_acme_withdrawal!
          redirect_to_acme_authority!("/settings/withdrawal")
        end
      end
    end
  end
end
