# typed: false
# frozen_string_literal: true

# Cancel-event entry point for sign-up cycles.
#
# Delegates to SignUpTermination, which handles cancel/expire/fail uniformly.
# Kept as a stable, intent-revealing API for controllers and tests.
class SignUpCancellation
  PHYSICAL_PURGE_DELAY = SignUpTermination::PHYSICAL_PURGE_DELAY

  def self.call(cycle:, actor_context:)
    SignUpTermination.call(cycle: cycle, event: :cancel, actor_context: actor_context)
  end
end
