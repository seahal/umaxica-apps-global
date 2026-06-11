# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Sign
      module Up
        class EntrancesController < ::Sign::Org::SignUpsController
          AUTHENTICATION_MODE = :guest
          declare_authentication_mode! :guest

          def show
            if params[:login_challenge].present?
              transaction =
                OidcAuthorizationTransactionService.find_by_login_challenge!(
                  surface: "org",
                  login_challenge: params[:login_challenge].to_s,
                )
              raise ActionController::BadRequest, "authorization transaction expired" if transaction.login_challenge_expired?
              raise ActionController::BadRequest, "authorization transaction already consumed" if transaction.consumed?

              session[:oidc_authorization_login_challenge] = transaction.login_challenge
              @oidc_authorization_intent = transaction.intent
            end
            render "sign/org/sign_ups/new"
          rescue ActiveRecord::RecordNotFound
            render plain: I18n.t("errors.messages.invalid_request", default: "Invalid request"),
                   status: :bad_request
          end
        end
      end
    end
  end
end
