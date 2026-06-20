# typed: false
# frozen_string_literal: true

module AcmeStepUpCancellation
  extend ActiveSupport::Concern

  private

  def cancel_step_up_ceremony!(surface:, actor:, token:, fallback:)
    now = Time.current
    transaction = latest_pending_step_up_transaction(surface:, actor:, token:, now:)
    transaction&.cancel!(canceled_at: now)

    Rails.logger.info(
      JitLogEvent.format(
        "auth.step_up.canceled",
        surface: surface,
        actor_type: actor.class.name,
        canceled: transaction.present?,
      ),
    )

    safe_redirect_to(
      safe_internal_path(params[:return_to]) || fallback,
      fallback: fallback,
      status: :see_other,
    )
  end

  def latest_pending_step_up_transaction(surface:, actor:, token:, now:)
    IdentityStepUpCeremonyReplayStore.for(surface).latest_pending_for(
      actor_ref: actor.public_id,
      session_ref: token.public_id,
      required_scope: step_up_scope_for(surface),
      now: now,
    )
  end

  def step_up_scope_for(_surface)
    params[:scope].presence
  end
end
