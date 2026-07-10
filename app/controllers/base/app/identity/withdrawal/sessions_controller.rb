# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      module Withdrawal
        # Withdrawal ceremony session lifecycle: re-entry via email OTP
        # (new/create, see WithdrawalCeremonyReentry) and ceremony sign-out
        # (destroy).
        class SessionsController < ::Base::App::Identity::BaseController
          include CommonRedirect
          include WithdrawalCeremonyReentry

          AUTHENTICATION_MODE = :open
          declare_authentication_mode! :open

          rate_limit(
            to: 5,
            within: 1.minute,
            by: -> { request.remote_ip },
            scope: "base_app_withdrawal_reentry",
            name: "email_create_ip_burst",
            store: rate_limit_store,
            only: :create,
            with: -> {
              render_rate_limited(rule_name: "base_app_withdrawal_reentry_email_create_ip_burst", retry_after: 60)
            },
          )

          # DELETE /identity/withdrawal/session
          # Ends the current withdrawal ceremony and returns to the sign-in surface.
          def destroy
            revoke_current_withdrawal_ceremony!
            safe_redirect_to(
              withdrawal_public_fallback_path,
              fallback: new_base_app_identity_withdrawal_path(ri: params[:ri]),
              status: :see_other,
            )
          end

          private

          def identity_email_model = ClientEmail

          def withdrawal_subject_from_email(email) = email&.user

          def withdrawal_reentry_surface = :app

          def withdrawal_ceremony_class = ClientWithdrawalCeremony

          def withdrawal_new_path(extra_params = {})
            new_base_app_identity_withdrawal_session_path({ ri: params[:ri] }.merge(extra_params))
          end

          def withdrawal_edit_path = edit_base_app_identity_withdrawal_path(ri: params[:ri])

          def withdrawal_public_fallback_path = auth_app_sign_in_path
        end
      end
    end
  end
end
