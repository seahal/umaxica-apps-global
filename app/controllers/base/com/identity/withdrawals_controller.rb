# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Identity
      class WithdrawalsController < ::Base::Com::ApplicationController
        include ::VerificationVisitor
        include CommonRedirect
        include BaseSettingsWithdrawalFlow
        include WithdrawalCeremonyAuthentication

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open

        before_action :authenticate_visitor!, only: %i(new update)
        before_action :withdrawal_ceremony_required!, only: %i(edit create destroy)
        before_action :authorize_withdrawal!, only: %i(new update)
        before_action :authorize_withdrawal_ceremony!, only: %i(edit create destroy)

        def new
          render_withdrawal_entry(current_visitor)
          render "base/com/identity/withdrawals/new" unless performed?
        end

        def edit
          render_withdrawal_status(current_withdrawal_subject)
          render "base/com/identity/withdrawals/edit" unless performed?
        end

        def create
          recover_withdrawal!(current_withdrawal_subject)
        end

        def update
          update_withdrawal!(current_visitor)
        end

        def destroy
          terminate_withdrawal!(current_withdrawal_subject)
        end

        private

        def authorize_withdrawal!
          authorize!(current_visitor, to: :"#{action_name}?", with: VisitorWithdrawalPolicy)
        end

        def authorize_withdrawal_ceremony!
          authorize!(
            current_withdrawal_subject,
            to: :"#{action_name}?",
            with: VisitorWithdrawalPolicy,
            context: { user: current_withdrawal_subject },
          )
        end

        def withdrawal_ceremony_class = VisitorWithdrawalCeremony

        def withdrawal_new_path(extra_params = {})
          new_base_com_identity_withdrawal_path({ ri: params[:ri] }.merge(extra_params))
        end

        def withdrawal_session_new_path
          new_base_com_identity_withdrawal_session_path(ri: params[:ri])
        end

        def withdrawal_edit_path
          edit_base_com_identity_withdrawal_path(ri: params[:ri])
        end

        def withdrawal_settings_path
          base_com_identity_withdrawal_path(ri: params[:ri])
        end

        def withdrawal_public_fallback_path
          auth_com_sign_in_path
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

        def verification_required_action? = action_name.in?(%w(new update))

        def verification_scope = "withdrawal"
      end
    end
  end
end
