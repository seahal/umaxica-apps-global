# typed: false
# frozen_string_literal: true

class SignInStateMachine
  PRIMARY_VERIFIED_TRANSITIONS = {
    checkpoint: ["CHECKPOINT_PENDING", "checkpoint"],
    selector: ["SELECTOR_PENDING", "selector"],
  }.freeze

  def self.after_session_issued(checkpoint_required:)
    participant = checkpoint_required ? :checkpoint : :selector
    state, participant_name = PRIMARY_VERIFIED_TRANSITIONS.fetch(participant)

    { state: state, participant: participant_name }
  end
end
