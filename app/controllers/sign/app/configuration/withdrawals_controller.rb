# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Configuration
      class WithdrawalsController < PrivateController
        include ::Verification::Client
        include Common::Redirect

        before_action :authenticate_client!

        def new
          build_forms
          @schedule_confirmed = current_client.closing?
          @terminated = current_client.terminated?

          return unless params.key?(:ack_schedule_purge)

          if @schedule_form.valid?
            @schedule_confirmed = true
          else
            render :new, status: :unprocessable_content
          end
        end

        def edit
          unless current_client.withdrawal_in_progress? || current_client.terminated?
            return safe_redirect_to(
              new_sign_app_configuration_withdrawal_path(ri: params[:ri]),
              fallback: sign_app_configuration_path(ri: params[:ri]),
              status: :see_other,
            )
          end

          assign_status_view_state(current_client)
        end

        def create
          unless current_client.can_recover?
            return safe_redirect_to(
              edit_sign_app_configuration_withdrawal_path(ri: params[:ri]),
              fallback: new_sign_app_configuration_withdrawal_path(ri: params[:ri]),
              status: :see_other,
            )
          end

          ::Withdrawal::Lifecycle.recover!(actor: current_client, request: request)

          safe_redirect_to(
            sign_app_configuration_path(ri: params[:ri]),
            fallback: "/configuration",
            status: :see_other,
          )
        end

        def update
          build_forms

          return start_closing! if should_start_closing?

          unless @deactivate_form.valid?
            return render_update_validation_error
          end

          ::Withdrawal::Lifecycle.suspend!(
            actor: current_client,
            current_session_public_id: current_session_public_id,
            request: request,
          )

          safe_redirect_to(
            edit_sign_app_configuration_withdrawal_path(ri: params[:ri]),
            fallback: sign_app_configuration_path(ri: params[:ri]),
            status: :see_other,
            notice: t("sign.app.configuration.withdrawal.deactivate.success"),
          )
        rescue ActiveRecord::RecordInvalid
          handle_deactivation_failure
        end

        def destroy
          ::Withdrawal::Lifecycle.terminate!(
            actor: current_client,
            request: request,
          ) if current_client.early_terminatable?

          safe_redirect_to(
            edit_sign_app_configuration_withdrawal_path(ri: params[:ri]),
            fallback: sign_app_configuration_path(ri: params[:ri]),
            status: :see_other,
          )
        end

        private

        def build_forms
          @schedule_form = Withdrawal::ScheduleForm.new(schedule_params)
          @deactivate_form = Withdrawal::DeactivateForm.new(deactivate_params)
        end

        def should_start_closing?
          !current_client.closing? && !params.key?(:ack_deactivate_today)
        end

        def start_closing!
          unless @schedule_form.valid?
            @schedule_confirmed = false
            return render :new, status: :unprocessable_content
          end

          ::Withdrawal::Lifecycle.start!(
            actor: current_client,
            current_session_public_id: current_session_public_id,
            request: request,
          )

          safe_redirect_to(
            new_sign_app_configuration_withdrawal_path(ri: params[:ri], ack_schedule_purge: "1"),
            fallback: sign_app_configuration_path(ri: params[:ri]),
            status: :see_other,
          )
        end

        def assign_status_view_state(actor)
          @recovery_available_at = actor.recovery_available_at
          @recovery_deadline = actor.recovery_deadline
          @early_termination_available_at = actor.early_termination_available_at
          @recoverable = actor.can_recover?
          @early_terminatable = actor.early_terminatable?
          @terminated = actor.terminated?
        end

        def schedule_params
          params.permit(:ack_schedule_purge)
        end

        def deactivate_params
          params.permit(:ack_deactivate_today)
        end

        def render_update_validation_error
          @schedule_confirmed = true
          render :new, status: :unprocessable_content
        end

        def handle_deactivation_failure
          Rails.logger.info(
            LogEvent.format(
              "user.withdrawal.suspension_failed",
              user_id: current_client.id,
              errors: current_client.errors.full_messages,
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
