# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Sign
      class UpsController < ::Auth::Org::ApplicationController
        include SignUpSuspensionGuard

        AUTHENTICATION_MODE = :guest

        before_action :reject_suspended_sign_up!
        helper Auth::Org::SignUpsHelper
        declare_authentication_mode! :guest, no_redirect: true
        skip_before_action :set_region, raise: false

        def show
          return reject_logged_in_direct_entry! if logged_in? && params[:login_challenge].blank?
          return render_method_selection! if params[:login_challenge].blank?

          transaction =
            OidcAuthorizationTransactionCoordinator.find_by_login_challenge!(
              surface: "org",
              login_challenge: params[:login_challenge].to_s,
            )
          raise ActionController::BadRequest,
                "authorization transaction expired" if transaction.login_challenge_expired?
          raise ActionController::BadRequest, "authorization transaction already consumed" if transaction.consumed?
          raise ActionController::BadRequest,
                "authorization transaction intent mismatch" unless transaction.intent == "sign_up"

          session[:oidc_authorization_login_challenge] = transaction.login_challenge
          @oidc_authorization_intent = transaction.intent
          render "auth/org/sign_ups/new"
        rescue ActiveRecord::RecordNotFound
          render plain: I18n.t("errors.messages.invalid_request", default: "Invalid request"),
                 status: :bad_request
        end

        private

        def sign_up_surface = :org

        def reject_logged_in_direct_entry!
          render plain: I18n.t("errors.messages.already_authenticated"), status: :forbidden
        end

        # Direct entry without an authorization transaction renders this surface's entry page instead
        # of bouncing through Base. Every page it links to is already reachable directly, and the
        # completion paths branch on a missing `oidc_authorization_login_challenge`.
        def render_method_selection!
          render "auth/org/sign_ups/new"
        end
      end
    end
  end
end
