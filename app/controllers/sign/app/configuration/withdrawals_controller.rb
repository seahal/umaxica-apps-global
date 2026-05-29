# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Configuration
      class WithdrawalsController < Sign::App::ApplicationController
        include ::Verification::Client
        include Common::Redirect
        include Sign::Configuration::WithdrawalFlow

        AUTHENTICATION_MODE = :private

        before_action :authenticate_client!

        def new
          render_withdrawal_entry(current_client)
        end

        def edit
          render_withdrawal_status(current_client)
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

        def withdrawal_new_path(extra_params = {})
          new_sign_app_configuration_withdrawal_path({ ri: params[:ri] }.merge(extra_params))
        end

        def withdrawal_edit_path
          edit_sign_app_configuration_withdrawal_path(ri: params[:ri])
        end

        def withdrawal_configuration_path
          sign_app_configuration_path(ri: params[:ri])
        end

        def handle_deactivation_failure(actor)
          Rails.logger.info(
            LogEvent.format(
              "user.withdrawal.suspension_failed",
              user_id: actor.id,
              errors: actor.errors.full_messages,
              ip_address: request.remote_ip,
            ),
          )
          @schedule_confirmed = true
          render :new, status: :unprocessable_content
        end

        def verification_required_action?
          true
        end

        def verification_scope
          "withdrawal"
        end
      end
    end
  end
end
