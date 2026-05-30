# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Configuration
      class GooglesController < Sign::Org::ApplicationController
        include SocialAuthConcern

        AUTHENTICATION_MODE = :private

        before_action :authenticate_operator!

        # Object-level authorization (ActionPolicy): the Google link-status page reads the operator's
        # own account, so gate owner-self via OperatorPolicy#show?.
        def show
          authorize!(current_operator, to: :show?)
          @google_login_enabled = google_login_enabled?
        end

        # Object-level authorization (ActionPolicy): initiating a Google link modifies the operator's
        # own linked identities, so gate owner-self via OperatorPolicy#update?. The link binds to
        # current_operator only; state validation / intent binding remain the primary protections
        # (see notes/implementation/2026-05-30-omniauth-callbacks-object-authz-out-of-scope.md).
        # Placed before prepare_social_auth_intent!; ActionPolicy::Unauthorized is not a
        # SocialAuth::BaseError, so the rescue below does not swallow it.
        def create
          authorize!(current_operator, to: :update?)
          state = prepare_social_auth_intent!("link", provider: "google_org")

          safe_redirect_to(
            omniauth_authorize_path("google_org", state: state),
            fallback: new_sign_org_sign_in_path,
          )
        rescue SocialAuth::BaseError => e
          handle_social_auth_error(e)
        end

        private

        def google_login_enabled?
          current_operator.operator_google_identity&.active?
        end
      end
    end
  end
end
