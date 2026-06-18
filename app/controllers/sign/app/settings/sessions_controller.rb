# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Settings
      class SessionsController < ::Sign::App::ApplicationController
        include ::SignAcmeAuthorityRedirect

        AUTHENTICATION_MODE = :private

        before_action :authenticate_client!

        def index = redirect_to_acme_sessions!

        def show = redirect_to_acme_sessions!

        def destroy = redirect_to_acme_sessions!

        def others = redirect_to_acme_sessions!

        def revoke_all = redirect_to_acme_sessions!

        private

        # sign/id is redirect-only here. acme/www owns session management.
        def redirect_to_acme_sessions!
          redirect_to_acme_authority!("/sign/settings/sessions")
        end
      end
    end
  end
end
