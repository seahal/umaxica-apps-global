# typed: false
# frozen_string_literal: true

# Shared controller behavior for social sign-up birthdate check steps (Apple and Google).
# Include after SignUpExplicitStepControllerSupport and SignUpSocialBirthdateSupport.
module SignUpSocialCheckBirthdateControllerSupport
  extend ActiveSupport::Concern

  def show
    return unless load_gate_context!(gate_for_show)

    render_sign_up_checkpoint
  end

  def update
    return unless load_gate_context!(gate_for_update)

    clear_sign_up_birthdate_requirement
  end

  def destroy
    cancel_from_explicit_step
  end

  private

  def sign_up_surface = :app

  def sign_up_ticket_class = ClientSignUpFlow

  def sign_up_sequence_session_key = :sign_app_up_sequence_id

  def sign_up_step = :birthdate

  def render_sign_up_checkpoint
    @sign_up_missing_requirements = sign_up_missing_requirements
    @sign_up_completed_requirements = @sign_up_ticket.completed_requirements
    @sign_up_pending_actor = sign_up_pending_actor

    render "auth/app/sign/up/checkpoints/show", status: :ok
  end
end
