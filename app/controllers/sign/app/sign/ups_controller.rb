# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Sign
      class UpsController < ::Sign::App::ApplicationController
        # Use :open instead of :guest so already-authenticated users reach the
        # action body and get redirected to their dashboard (see
        # `redirect_logged_in_direct_entry!`) instead of receiving a 403 from
        # the guest enforcement. Matches the sibling InsController policy.
        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        skip_before_action :set_region, raise: false

        def show
          return redirect_logged_in_direct_entry! if logged_in? && params[:login_challenge].blank?
          return normalize_to_acme_authorize! if params[:login_challenge].blank?

          transaction =
            OidcAuthorizationTransactionService.find_by_login_challenge!(
              surface: "app",
              login_challenge: params[:login_challenge].to_s,
            )
          raise ActionController::BadRequest,
                "authorization transaction expired" if transaction.login_challenge_expired?
          raise ActionController::BadRequest, "authorization transaction already consumed" if transaction.consumed?
          raise ActionController::BadRequest,
                "authorization transaction intent mismatch" unless transaction.intent == "sign_up"

          session[:oidc_authorization_login_challenge] = transaction.login_challenge
          @oidc_authorization_intent = transaction.intent
          render "sign/app/sign_ups/new"
        rescue ActiveRecord::RecordNotFound
          render plain: I18n.t("errors.messages.invalid_request", default: "Invalid request"),
                 status: :bad_request
        end

        private

        # Logged-in users hitting /sign/up directly are sent to their post-auth
        # landing instead of receiving a 403. The 403 surfaced as a hard error
        # in the cross-host redirect chain when the SSO handshake briefly
        # revisited this endpoint.
        def redirect_logged_in_direct_entry!
          redirect_to(sign_app_dashboard_path(ri: params[:ri]))
        end

        def normalize_to_acme_authorize!
          url = initiate_oidc_session!(pt: sign_app_root_path(ri: params[:ri]), screen_hint: "signup")
          redirect_to_oidc_authorization_url(url)
        end
      end
    end
  end
end
