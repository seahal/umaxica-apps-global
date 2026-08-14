# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      class InsController < ::Auth::App::ApplicationController
        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open

        def show
          return redirect_logged_in_direct_entry! if logged_in? && params[:login_challenge].blank?
          return render_method_selection! if params[:login_challenge].blank?

          transaction = load_sign_in_authorization_transaction!
          return redirect_signed_in_authorization_transaction!(transaction) if logged_in?

          session[:oidc_authorization_login_challenge] = transaction.login_challenge
          @oidc_authorization_intent = transaction.intent
          render "auth/app/sign_ins/new"
        rescue ActiveRecord::RecordNotFound
          render plain: I18n.t("errors.messages.invalid_request"),
                 status: :bad_request
        end

        private

        # Direct entry without an authorization transaction lists the sign-in methods instead of
        # bouncing through Base. Every method page it links to is already reachable directly, and
        # AuthenticationSequenceGate already branches on a missing
        # `oidc_authorization_login_challenge` after login, so no ceremony state is skipped here.
        def render_method_selection!
          render "auth/app/sign_ins/new"
        end

        def redirect_logged_in_direct_entry!
          redirect_to(
            base_app_dashboard_url(ri: current_region_identifier, host: base_authority_host),
            allow_other_host: true,
          )
        end

        def redirect_signed_in_authorization_transaction!(transaction)
          session.delete(:oidc_authorization_login_challenge)
          result = register_oidc_authorization_result!(transaction.login_challenge)
          redirect_to(result.resume_url, allow_other_host: true)
        end

        def load_sign_in_authorization_transaction!
          transaction =
            OidcAuthorizationTransactionCoordinator.find_by_login_challenge!(
              surface: "app",
              login_challenge: params[:login_challenge].to_s,
            )
          raise ActionController::BadRequest,
                "authorization transaction expired" if transaction.login_challenge_expired?
          raise ActionController::BadRequest, "authorization transaction already consumed" if transaction.consumed?
          raise ActionController::BadRequest,
                "authorization transaction intent mismatch" unless transaction.intent == "sign_in"

          transaction
        end
      end
    end
  end
end
