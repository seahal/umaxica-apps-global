# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Settings
      class WithdrawalsController < Sign::App::ApplicationController
        include ::Sign::SettingsAuthorityRedirect
        include ::Verification::Client
        include Acme::Settings::WithdrawalFlow

        AUTHENTICATION_MODE = :private

        before_action :require_withdrawal_step_up_when_available!, only: %i(new edit create update destroy)

        def new
          return redirect_to_acme_withdrawal! unless local_withdrawal_flow?

          render_withdrawal_entry(current_client)
          render "sign/app/settings/withdrawals/new" unless performed?
        end

        def edit
          return redirect_to_acme_withdrawal! unless local_withdrawal_flow?

          render_withdrawal_status(current_client)
          render "sign/app/settings/withdrawals/edit" unless performed?
        end

        def create
          return redirect_to_acme_withdrawal! unless local_withdrawal_flow?

          recover_withdrawal!(current_client)
        end

        def update
          return redirect_to_acme_withdrawal! unless local_withdrawal_flow?

          update_withdrawal!(current_client)
        end

        def destroy
          return redirect_to_acme_withdrawal! unless local_withdrawal_flow?

          terminate_withdrawal!(current_client)
        end

        private

        # sign/id is redirect-only here. acme/www owns withdrawal mutation.
        def redirect_to_acme_withdrawal!
          redirect_to_acme_authority!("/settings/withdrawal")
        end

        def require_withdrawal_step_up_when_available!
          return if withdrawal_restricted_resource?(current_client)
          return if (available_step_up_methods.map(&:to_sym) & %i(passkey totp)).blank?

          require_step_up!(scope: "withdrawal")
        end

        def local_withdrawal_flow?
          withdrawal_restricted_resource?(current_client) &&
            step_up_satisfied?(scope: "withdrawal")
        end

        def withdrawal_new_path(extra_params = {})
          new_sign_app_settings_withdrawal_path({ ri: params[:ri] }.merge(extra_params))
        end

        def withdrawal_edit_path
          edit_sign_app_settings_withdrawal_path(ri: params[:ri])
        end

        def withdrawal_settings_path
          sign_app_settings_withdrawal_path(ri: params[:ri])
        end

        def handle_deactivation_failure(actor)
          Rails.logger.info(
            Jit::LogEvent.format(
              "user.withdrawal.suspension_failed",
              user_id: actor.id,
              errors: actor.errors.full_messages,
              ip_address: request.remote_ip,
            ),
          )
          @schedule_confirmed = true
          render "sign/app/settings/withdrawals/new", status: :unprocessable_content
        end

        def render_update_validation_error
          @schedule_confirmed = true
          render "sign/app/settings/withdrawals/new", status: :unprocessable_content
        end
      end
    end
  end
end
