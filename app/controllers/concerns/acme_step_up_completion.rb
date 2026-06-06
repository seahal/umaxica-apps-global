# typed: false
# frozen_string_literal: true

module AcmeStepUpCompletion
  extend ActiveSupport::Concern

  private

  def complete_step_up_ceremony!(surface:, actor:, token:, fallback:)
    now = Time.current
    result_token = params.require(:step_up_ceremony_result)
    payload = IdentityStepUpCeremonyContract.decode_unverified_payload(result_token)
    raise ActionController::BadRequest, "surface mismatch" unless payload["surface"].to_s == surface.to_s

    transaction =
      IdentityStepUpCeremonyReplayStore
        .for(surface)
        .find_transaction!(payload.fetch("transaction_id"))
    raise IdentityStepUpCeremonyContract::Error,
          "transaction actor mismatch" unless transaction.actor_ref == actor.public_id
    raise IdentityStepUpCeremonyContract::Error,
          "transaction session mismatch" unless transaction.session_ref == token.public_id

    consumption = IdentityStepUpCeremonyResultConsumer.new(transaction: transaction, now: now).call(result_token)
    IdentityStepUpCeremonyFreshnessCommitter.call!(
      result_token: result_token,
      token: token,
      expected_scope: consumption.transaction.required_scope,
      expected_aal: consumption.transaction.required_aal,
      expected_method: consumption.transaction.method,
      audience: step_up_audience,
      now: now,
    )

    Actor.install_context!(
      step_up: StepUpResolver.call(
        token: token,
        requirement: step_up_requirement(scope: consumption.transaction.required_scope),
        now: now,
      ),
    ) if defined?(Actor)

    return_to = consumption.transaction.return_to.presence
    flash[:notice] = I18n.t("auth.step_up.completed", default: "Verification completed")
    safe_redirect_to(return_to, fallback: fallback, status: :see_other)
  rescue KeyError, ActiveRecord::RecordNotFound, IdentityStepUpCeremonyContract::Error => e
    Rails.logger.info(
      JitLogEvent.format(
        "auth.step_up.completion_failed",
        surface: surface,
        reason: e.class.name,
      ),
    )
    raise ActionController::BadRequest, "invalid step-up completion"
  end
end
