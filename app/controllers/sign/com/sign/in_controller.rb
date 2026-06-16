# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Sign
      class InController < ::Sign::Com::SignInsController
        AUTHENTICATION_MODE = :guest
        declare_authentication_mode! :guest
        skip_before_action :set_region, raise: false

        def show
          return normalize_to_acme_authorize! if params[:login_challenge].blank?

          transaction =
            OidcAuthorizationTransactionService.find_by_login_challenge!(
              surface: "com",
              login_challenge: params[:login_challenge].to_s,
            )
          raise ActionController::BadRequest,
                "authorization transaction expired" if transaction.login_challenge_expired?
          raise ActionController::BadRequest, "authorization transaction already consumed" if transaction.consumed?
          raise ActionController::BadRequest,
                "authorization transaction intent mismatch" unless transaction.intent == "sign_in"

          session[:oidc_authorization_login_challenge] = transaction.login_challenge
          @oidc_authorization_intent = transaction.intent
          render "sign/com/sign_ins/new"
        rescue ActiveRecord::RecordNotFound
          render plain: I18n.t("errors.messages.invalid_request", default: "Invalid request"),
                 status: :bad_request
        end

        private

        def normalize_to_acme_authorize!
          url = initiate_oidc_session!(pt: sign_com_root_path(ri: params[:ri]), screen_hint: "signin")
          redirect_to_oidc_authorization_url(url)
        end
      end
    end
  end
end
