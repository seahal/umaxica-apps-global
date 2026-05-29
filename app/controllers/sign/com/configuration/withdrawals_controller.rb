# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Configuration
      class WithdrawalsController < Sign::Com::ApplicationController
        include ::Verification::Visitor
        include Common::Redirect
        include Sign::Configuration::WithdrawalFlow

        AUTHENTICATION_MODE = :private

        before_action :authenticate_visitor!

        def new
          render_withdrawal_entry(current_visitor)
        end

        def edit
          render_withdrawal_status(current_visitor)
        end

        def create
          recover_withdrawal!(current_visitor)
        end

        def update
          update_withdrawal!(current_visitor)
        end

        def destroy
          terminate_withdrawal!(current_visitor)
        end

        private

        def withdrawal_new_path(extra_params = {})
          new_sign_com_configuration_withdrawal_path({ ri: params[:ri] }.merge(extra_params))
        end

        def withdrawal_edit_path
          edit_sign_com_configuration_withdrawal_path(ri: params[:ri])
        end

        def withdrawal_configuration_path
          sign_com_configuration_path(ri: params[:ri])
        end

        def handle_deactivation_failure(actor)
          Rails.logger.info(
            Jit::LogEvent.format(
              "visitor.withdrawal.suspension_failed",
              visitor_id: actor.id,
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
