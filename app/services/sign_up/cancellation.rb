# typed: false
# frozen_string_literal: true

module SignUp
  # Cancel-event entry point for sign-up cycles.
  #
  # Delegates to SignUp::Termination, which handles cancel/expire/fail uniformly.
  # Kept as a stable, intent-revealing API for controllers and tests.
  class Cancellation
    PHYSICAL_PURGE_DELAY = Termination::PHYSICAL_PURGE_DELAY

    def self.call(cycle:, actor_context:)
      Termination.call(cycle: cycle, event: :cancel, actor_context: actor_context)
    end
  end
end
