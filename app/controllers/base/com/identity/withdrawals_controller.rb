# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Identity
      class WithdrawalsController < ::Base::Com::ApplicationController
        include ::VerificationVisitor
        include CommonRedirect
        include BaseSettingsWithdrawalFlow

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_visitor!
        before_action :authorize_withdrawal!, only: %i(new edit create update destroy)

        def new
          render_withdrawal_entry(current_visitor)
          render "base/com/identity/withdrawals/new" unless performed?
        end

        def edit
          render_withdrawal_status(current_visitor)
          render "base/com/identity/withdrawals/edit" unless performed?
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

        def authorize_withdrawal!
          authorize!(current_visitor, to: :"#{action_name}?", with: VisitorWithdrawalPolicy)
        end

        def withdrawal_new_path(extra_params = {})
          new_base_com_identity_withdrawal_path({ ri: params[:ri] }.merge(extra_params))
        end

        def withdrawal_edit_path
          edit_base_com_identity_withdrawal_path(ri: params[:ri])
        end

        def withdrawal_settings_path
          base_com_identity_withdrawal_path(ri: params[:ri])
        end

        def handle_deactivation_failure(actor)
          Rails.logger.info(
            JitLogEvent.format(
              "visitor.withdrawal.suspension_failed",
              visitor_id: actor.id,
              errors: actor.errors.full_messages,
              ip_address: request.remote_ip,
            ),
          )
          @schedule_confirmed = true
          render "base/com/identity/withdrawals/new", status: :unprocessable_content
        end

        def render_update_validation_error
          @schedule_confirmed = true
          render "base/com/identity/withdrawals/new", status: :unprocessable_content
        end

        def verification_required_action? = true

        def verification_scope = "withdrawal"
      end
    end
  end
end
