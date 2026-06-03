# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Settings
      class WithdrawalsController < Sign::RedirectOnlyController
        def new = redirect_to_acme_withdrawal!

        def edit = redirect_to_acme_withdrawal!

        def create = redirect_to_acme_withdrawal!

        def update = redirect_to_acme_withdrawal!

        def destroy = redirect_to_acme_withdrawal!

        private

        # sign/id is redirect-only here. acme/www owns withdrawal mutation.
        def redirect_to_acme_withdrawal!
          redirect_to_acme_authority!("/settings/withdrawal")
        end
      end
    end
  end
end
