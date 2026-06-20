# typed: false
# frozen_string_literal: true

module SignUpExplicitStepControllerSupport
  extend ActiveSupport::Concern

  included do
    include SignUpSequenceControllerSupport
  end

  private

  def gate_for_show
    SignUpStepGate.for_show(
      controller: self, surface: sign_up_surface, family: sign_up_family,
      step: sign_up_step,
    )
  end

  def gate_for_create
    SignUpStepGate.for_create(
      controller: self, surface: sign_up_surface, family: sign_up_family,
      step: sign_up_step,
    )
  end

  def gate_for_update
    SignUpStepGate.for_update(
      controller: self, surface: sign_up_surface, family: sign_up_family,
      step: sign_up_step,
    )
  end

  def gate_for_destroy
    SignUpStepGate.for_destroy(
      controller: self, surface: sign_up_surface, family: sign_up_family,
      step: sign_up_step,
    )
  end

  def load_gate_context!(gate)
    unless gate.success?
      render_step_gate_failure(gate)
      return false
    end
    if gate.redirect?
      redirect_to(gate.redirect_to)
      return false
    end

    @sign_up_ticket = gate.ticket
    @sign_up_step_gate = gate
    true
  end

  def render_step_gate_failure(gate)
    return redirect_to_sign_in_sequence_after_completed_sign_up if completed_sign_up_handoff_request?(gate)

    render plain: gate.errors.to_sentence.presence || "invalid_sign_up_step", status: :unprocessable_content
  end

  def completed_sign_up_handoff_request?(gate)
    gate.errors.include?("ticket is required") &&
      Actor.authn.signed_in? &&
      respond_to?(:current_db_sign_in_flow_for_sequence, true) &&
      current_db_sign_in_flow_for_sequence.present?
  end

  def redirect_to_sign_in_sequence_after_completed_sign_up
    redirect_to_sign_in_sequence!(pt: sign_up_handoff_pt, status: :see_other)
  end

  def cancel_from_explicit_step
    return unless load_gate_context!(gate_for_destroy)

    result =
      if @sign_up_ticket.social_entry_method?
        SignAppUpSocialCancellation.call(cycle: @sign_up_ticket)
      else
        SignUpCancellation.call(cycle: @sign_up_ticket, actor_context: Actor.authn)
      end
    return render_sign_up_result(result) unless result.success?

    sign_up_session_state.clear_all!
    redirect_to(sign_up_restart_path, status: :see_other)
  end

  def clear_current_requirement!
    result = perform_sign_up_event(
      :clear_requirement,
      payload: { requirement: sign_up_step, checkpoint_version: sign_up_checkpoint_version_param },
    )
    return finalize_sign_up_from_checkpoint! if result.success? && result.next_event == :finalize
    return render_sign_up_result(result) unless result.success?

    redirect_to(next_explicit_step_path)
  end

  def next_explicit_step_path
    next_step = @sign_up_step_gate&.registry&.next_requirement(@sign_up_ticket.completed_requirements)
    return sign_up_restart_path unless next_step

    helper = SignUpStepGate::STEP_ROUTES.fetch(sign_up_surface).fetch(sign_up_family).fetch(next_step)
    public_send(helper, ri: params[:ri], pt: sign_up_handoff_pt)
  end
end
