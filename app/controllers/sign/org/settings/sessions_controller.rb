# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Settings
      class SessionsController < Sign::RedirectOnlyController
        def index = redirect_to_acme_sessions!

        def destroy = redirect_to_acme_sessions!

        def others = redirect_to_acme_sessions!

        def revoke_all = redirect_to_acme_sessions!

        private

        # sign/id is redirect-only here. acme/www owns session management.
        def redirect_to_acme_sessions!
          redirect_to_acme_authority!("/settings/sessions")
        end
      end
    end
  end
end
