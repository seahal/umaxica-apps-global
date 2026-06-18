# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Sign
      class InController < ::Sign::App::ApplicationController
        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        skip_before_action :set_region, raise: false

        def show
          return redirect_signed_in_direct_entry! if logged_in? && params[:login_challenge].blank?
          return normalize_to_acme_authorize! if params[:login_challenge].blank?

          transaction = load_sign_in_authorization_transaction!
          return redirect_signed_in_authorization_transaction!(transaction) if logged_in?

          session[:oidc_authorization_login_challenge] = transaction.login_challenge
          @oidc_authorization_intent = transaction.intent
          render "sign/app/sign_ins/new"
        rescue ActiveRecord::RecordNotFound
          render plain: I18n.t("errors.messages.invalid_request", default: "Invalid request"),
                 status: :bad_request
        end

        private

        def normalize_to_acme_authorize!
          url = initiate_oidc_session!(pt: sign_app_root_path(ri: params[:ri]), screen_hint: "signin")
          redirect_to_oidc_authorization_url(url)
        end

        def redirect_signed_in_direct_entry!
          redirect_to after_login_path, allow_other_host: after_login_allows_other_host?
        end

        def redirect_signed_in_authorization_transaction!(transaction)
          session.delete(:oidc_authorization_login_challenge)
          result = register_oidc_authorization_result!(transaction.login_challenge)
          redirect_to result.resume_url, allow_other_host: true
        end

        def load_sign_in_authorization_transaction!
          transaction =
            OidcAuthorizationTransactionService.find_by_login_challenge!(
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
