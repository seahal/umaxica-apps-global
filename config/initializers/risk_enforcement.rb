# typed: false
# frozen_string_literal: true

# RISK_ENFORCEMENT_DISABLED turns off session-risk enforcement wholesale:
# SignRiskEnforcer stops revoking token sets on refresh-token reuse and stops
# forcing step-up, and SignRiskEmitter stops recording risk events at all. A
# control that can be switched off by one environment variable must at least
# announce that it is off, otherwise an incident review cannot tell whether the
# absence of risk events means "no risk observed" or "nothing was watching".
#
# Runs in after_initialize so JitLogEvent is loadable; autoloading during
# initializer execution is not guaranteed.
Rails.application.config.after_initialize do
  if ENV["RISK_ENFORCEMENT_DISABLED"] == "true"
    Rails.logger.warn(
      JitLogEvent.format(
        "security.risk_enforcement.disabled",
        rails_env: Rails.env,
        reason: "RISK_ENFORCEMENT_DISABLED=true",
      ),
    )
  end
end
