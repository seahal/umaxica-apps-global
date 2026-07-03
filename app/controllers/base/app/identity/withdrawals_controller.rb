# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      class WithdrawalsController < BaseController
        include VerificationClient

        include BaseSettingsWithdrawalFlow
        include WithdrawalCeremonyAuthentication

        AUTHENTICATION_MODE = :open

        declare_authentication_mode! :open

        before_action :authenticate_client!, only: %i(new update)
        before_action :withdrawal_ceremony_required!, only: %i(edit create destroy)
        before_action :authorize_withdrawal!, only: %i(new update)
        before_action :authorize_withdrawal_ceremony!, only: %i(edit create destroy)
        def new
          render_withdrawal_entry(current_client); render "base/app/identity/withdrawals/new" unless performed?
        end

        def edit
          render_withdrawal_status(current_withdrawal_subject); render "base/app/identity/withdrawals/edit" unless performed?
        end

        def create = recover_withdrawal!(current_withdrawal_subject)

        def update = update_withdrawal!(current_client)

        def destroy = terminate_withdrawal!(current_withdrawal_subject)

        def end_session
          revoke_current_withdrawal_ceremony!
          safe_redirect_to(withdrawal_public_fallback_path, fallback: withdrawal_new_path, status: :see_other)
        end

        private

        def authorize_withdrawal! = authorize!(current_client, to: :"#{action_name}?", with: ClientWithdrawalPolicy)

        def authorize_withdrawal_ceremony!
          authorize!(
            current_withdrawal_subject,
            to: :"#{action_name}?",
            with: ClientWithdrawalPolicy,
            context: { user: current_withdrawal_subject },
          )
        end

        def withdrawal_ceremony_class = ClientWithdrawalCeremony

        def withdrawal_new_path(extra_params = {})
          new_base_app_identity_withdrawal_path({ ri: params[:ri] }.merge(extra_params))
        end

        def withdrawal_session_new_path
          new_base_app_identity_withdrawal_session_path(ri: params[:ri])
        end

        def withdrawal_edit_path = edit_base_app_identity_withdrawal_path(ri: params[:ri])

        def withdrawal_settings_path = base_app_identity_withdrawal_path(ri: params[:ri])

        def withdrawal_public_fallback_path = auth_app_sign_in_path

        def handle_deactivation_failure(_actor)
          @schedule_confirmed = true; render "base/app/identity/withdrawals/new", status: :unprocessable_content
        end

        def render_update_validation_error
          @schedule_confirmed = true; render "base/app/identity/withdrawals/new", status: :unprocessable_content
        end

        def verification_required_action? = action_name.in?(%w(new update))

        def verification_scope = "withdrawal"
      end
    end
  end
end
