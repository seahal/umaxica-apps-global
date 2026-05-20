# typed: false
# frozen_string_literal: true

module SignIn
  class StateMachine
    TERMINAL_RESULT_STATUSES = {
      session_limit_hard_reject: :forbidden,
      guardrail_blocked: :forbidden,
      login_forbidden: :forbidden,
      credential_failed: :unauthorized,
      invalid_request: :bad_request,
    }.freeze

    SESSION_ISSUED_TRANSITIONS = {
      checkpoint: ["CHECKPOINT_PENDING", "checkpoint"],
      dashboard: ["DASHBOARD_PENDING", "dashboard"],
    }.freeze

    def self.after_session_issued(checkpoint_required:)
      participant = checkpoint_required ? :checkpoint : :dashboard
      state, participant_name = SESSION_ISSUED_TRANSITIONS.fetch(participant)

      { state: state, participant: participant_name }
    end

    def self.terminal_status?(status)
      TERMINAL_RESULT_STATUSES.key?(status.to_sym)
    end

    def self.http_status_for(status)
      TERMINAL_RESULT_STATUSES.fetch(status.to_sym)
    end
  end
end
