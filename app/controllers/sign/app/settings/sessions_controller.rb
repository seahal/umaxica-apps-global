# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Settings
      class SessionsController < Sign::App::ApplicationController
        include ::Sign::AcmeAuthorityRedirect
        include Acme::Settings::SessionManagement

        AUTHENTICATION_MODE = :open

        helper_method :current_session_record?

        def index
          return redirect_to_acme_sessions! unless logged_in?

          super
          render "sign/app/settings/sessions/index" unless performed?
        end

        def destroy = redirect_to_acme_sessions!

        def others = redirect_to_acme_sessions!

        def revoke_all = redirect_to_acme_sessions!

        private

        # sign/id is redirect-only here. acme/www owns session management.
        def redirect_to_acme_sessions!
          redirect_to_acme_authority!("/settings/sessions")
        end

        def visible_sessions
          current_client.client_tokens.session_inventory
        end

        def session_owner
          current_client
        end

        def revoke_all_reason
          "app_user_logout_all_sessions"
        end
      end
    end
  end
end
