# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      class UpsController < ::Auth::App::ApplicationController
        # Use :open instead of :guest so already-authenticated users reach the
        # action body and get redirected to their dashboard (see
        # `redirect_logged_in_direct_entry!`) instead of receiving a 403 from
        # the guest enforcement. Matches the sibling InsController policy.
        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        skip_before_action :set_region, raise: false

        def show
          return redirect_logged_in_direct_entry! if logged_in? && params[:login_challenge].blank?
          return render_method_selection! if params[:login_challenge].blank?

          transaction =
            OidcAuthorizationTransactionCoordinator.find_by_login_challenge!(
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
          render "auth/app/sign_ups/new"
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
          redirect_to(base_app_dashboard_url(ri: params[:ri], host: base_authority_host), allow_other_host: true)
        end

        # Direct entry without an authorization transaction lists the registration methods instead
        # of bouncing through Base. The round trip dropped `ri`, so every link on the returned page
        # needed a further redirect to restore it. Sign-up finalization never reads
        # `oidc_authorization_login_challenge`; it hands off to the sign-in sequence, which already
        # branches on a missing challenge.
        def render_method_selection!
          render "auth/app/sign_ups/new"
        end
      end
    end
  end
end
