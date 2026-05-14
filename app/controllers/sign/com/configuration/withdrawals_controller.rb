# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Configuration
      class WithdrawalsController < ApplicationController
        auth_required!

        include ::Verification::User
        include Common::Redirect

        before_action :authenticate_visitor!

        def new
          @schedule_form = Sign::App::Configuration::Withdrawal::ScheduleForm.new(schedule_params)
          @deactivate_form = Sign::App::Configuration::Withdrawal::DeactivateForm.new
          @schedule_confirmed = false

          return unless params.key?(:ack_schedule_purge)

          if @schedule_form.valid?
            @schedule_confirmed = true
          else
            render :new, status: :unprocessable_content
          end
        end

        def edit
          unless current_visitor.deactivated?
            return safe_redirect_to(
              new_sign_com_configuration_withdrawal_path(ri: params[:ri]),
              fallback: sign_com_configuration_path(ri: params[:ri]),
              status: :see_other,
            )
          end

          @recovery_deadline = current_visitor.deactivated_at + recovery_period
          @recoverable = recoverable_withdrawal?
        end

        def create
          unless recoverable_withdrawal?
            return safe_redirect_to(
              edit_sign_com_configuration_withdrawal_path(ri: params[:ri]),
              fallback: new_sign_com_configuration_withdrawal_path(ri: params[:ri]),
              status: :see_other,
            )
          end

          Visitor.transaction do
            current_visitor.update!(
              withdrawal_started_at: nil,
              deactivated_at: nil,
              lapses_at: Float::INFINITY,
              purge_at: Float::INFINITY,
              withdrawn_at: nil,
            )

            Rails.event.notify(
              "visitor.withdrawal.recovered",
              visitor_id: current_visitor.id,
              ip_address: request.remote_ip,
            )
          end

          safe_redirect_to(
            sign_com_configuration_path(ri: params[:ri]),
            fallback: "/configuration",
            status: :see_other,
          )
        end

        def update
          @schedule_form = Sign::App::Configuration::Withdrawal::ScheduleForm.new(ack_schedule_purge: "1")
          @deactivate_form = Sign::App::Configuration::Withdrawal::DeactivateForm.new(deactivate_params)

          unless @deactivate_form.valid?
            return render_update_validation_error
          end

          deactivate_user!

          safe_redirect_to(
            edit_sign_com_configuration_path(ri: params[:ri]),
            fallback: sign_com_configuration_path(ri: params[:ri]),
            status: :see_other,
          )
        rescue ActiveRecord::RecordInvalid
          handle_deactivation_failure
        end

        def destroy
          safe_redirect_to(
            edit_sign_com_configuration_withdrawal_path(ri: params[:ri]),
            fallback: sign_com_configuration_path(ri: params[:ri]),
            status: :see_other,
          )
        end

        private

        def recoverable_withdrawal?
          return false if current_visitor.deactivated_at.blank?

          Time.current < current_visitor.deactivated_at + recovery_period
        end

        def recovery_period
          31.days
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

        def deactivate_user!
          now = Time.current

          Visitor.transaction do
            assign_withdrawal_schedule!(now)
            current_visitor.save!
            notify_deactivation!
          end
        end

        def assign_withdrawal_schedule!(now)
          current_visitor.withdrawal_started_at ||= now
          current_visitor.deactivated_at ||= now
          deactivated = current_visitor.deactivated_at
          current_visitor.lapses_at = deactivated
          current_visitor.purge_at = deactivated + 31.days
        end

        def notify_deactivation!
          Rails.event.notify(
            "visitor.withdrawal.deactivated",
            visitor_id: current_visitor.id,
            deactivated_at: current_visitor.deactivated_at,
            purge_at: current_visitor.purge_at,
            ip_address: request.remote_ip,
          )
        end

        def handle_deactivation_failure
          Rails.event.notify(
            "visitor.withdrawal.deactivation_failed",
            visitor_id: current_visitor.id,
            errors: current_visitor.errors.full_messages,
            ip_address: request.remote_ip,
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
