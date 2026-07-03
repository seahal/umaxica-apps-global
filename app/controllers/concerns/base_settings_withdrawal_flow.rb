# typed: false
# frozen_string_literal: true

module BaseSettingsWithdrawalFlow
  extend ActiveSupport::Concern

  private

  def render_withdrawal_entry(actor)
    build_forms
    @schedule_confirmed = withdrawal_flow_closing_or_later?(actor)
    @terminated = actor.terminated?

    return unless params.key?(:ack_schedule_purge)

    if @schedule_form.valid?
      @schedule_confirmed = true
    else
      render :new, status: :unprocessable_content
    end
  end

  def render_withdrawal_status(actor)
    unless actor.withdrawal_in_progress? || actor.terminated?
      return safe_redirect_to(
        withdrawal_new_path,
        fallback: withdrawal_settings_path,
        status: :see_other,
      )
    end

    assign_status_view_state(actor)
  end

  def recover_withdrawal!(actor)
    unless actor.can_recover?
      return safe_redirect_to(
        withdrawal_edit_path,
        fallback: withdrawal_new_path,
        status: :see_other,
      )
    end

    ::WithdrawalLifecycle.recover!(actor: actor, request: request)
    consume_current_withdrawal_ceremony!

    safe_redirect_to(
      withdrawal_public_fallback_path,
      fallback: withdrawal_new_path,
      status: :see_other,
    )
  end

  def update_withdrawal!(actor)
    build_forms

    return start_withdrawal_request!(actor) if should_start_withdrawal_request?(actor)

    unless @deactivate_form.valid?
      return render_update_validation_error
    end

    ::WithdrawalLifecycle.suspend!(
      actor: actor,
      current_session_public_id: withdrawal_current_session_public_id,
      request: request,
    )
    clear_auth_cookies!
    issue_withdrawal_ceremony!(subject: actor, purpose: "status")

    safe_redirect_to(
      withdrawal_edit_path,
      fallback: withdrawal_settings_path,
      status: :see_other,
    )
  rescue ActiveRecord::RecordInvalid
    handle_deactivation_failure(actor)
  end

  def terminate_withdrawal!(actor)
    ::WithdrawalLifecycle.terminate!(actor: actor, request: request) if actor.early_terminatable?
    consume_current_withdrawal_ceremony!

    safe_redirect_to(
      withdrawal_public_fallback_path,
      fallback: withdrawal_new_path,
      status: :see_other,
    )
  end

  def build_forms
    @schedule_form = Sign::App::Settings::Withdrawal::ScheduleForm.new(schedule_params)
    @deactivate_form = Sign::App::Settings::Withdrawal::DeactivateForm.new(deactivate_params)
  end

  def should_start_withdrawal_request?(actor)
    !withdrawal_flow_closing_or_later?(actor) && !params.key?(:ack_deactivate_today)
  end

  def start_withdrawal_request!(actor)
    unless @schedule_form.valid?
      @schedule_confirmed = false
      return render :new, status: :unprocessable_content
    end

    ::WithdrawalLifecycle.start!(
      actor: actor,
      current_session_public_id: withdrawal_current_session_public_id,
      request: request,
    )

    safe_redirect_to(
      withdrawal_new_path(ack_schedule_purge: "1"),
      fallback: withdrawal_settings_path,
      status: :see_other,
    )
  end

  def withdrawal_flow_closing_or_later?(actor)
    cycle = active_withdrawal_flow_for(actor)
    return true if cycle&.withdrawal_closing?
    return true if cycle&.withdrawal_discarded?

    actor.closing? || actor.deactivated? || actor.terminated?
  end

  def active_withdrawal_flow_for(actor)
    case actor
    when Client
      actor.client_withdrawal_flows.active.recent_first.first
    when Visitor
      actor.visitor_withdrawal_flows.active.recent_first.first
    end
  end

  def withdrawal_current_session_public_id
    current_session_public_id.presence ||
      instance_variable_get(:@current_token_public_id).presence ||
      (current_session.public_id if respond_to?(:current_session, true))
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
end
