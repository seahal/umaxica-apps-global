# typed: false
# frozen_string_literal: true

module Acme
  module App
    module Settings
      class WithdrawalsController < Acme::App::ApplicationController
        include ::Verification::Client
        include Common::Redirect
        include Acme::Settings::WithdrawalFlow

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_client!
        before_action :authorize_withdrawal!, only: %i(new edit create update destroy)

        def new
          render_withdrawal_entry(current_client)
          render "sign/app/settings/withdrawals/new" unless performed?
        end

        def edit
          render_withdrawal_status(current_client)
          render "sign/app/settings/withdrawals/edit" unless performed?
        end

        def create
          recover_withdrawal!(current_client)
        end

        def update
          update_withdrawal!(current_client)
        end

        def destroy
          terminate_withdrawal!(current_client)
        end

        private

        def authorize_withdrawal!
          authorize!(current_client, to: :"#{action_name}?", with: ClientWithdrawalPolicy)
        end

        def withdrawal_new_path(extra_params = {})
          new_acme_app_settings_withdrawal_path({ ri: params[:ri] }.merge(extra_params))
        end

        def withdrawal_edit_path
          edit_acme_app_settings_withdrawal_path(ri: params[:ri])
        end

        def withdrawal_settings_path
          acme_app_settings_withdrawal_path(ri: params[:ri])
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

        def verification_required_action? = true

        def verification_scope = "withdrawal"
      end
    end
  end
end
