# typed: false
# frozen_string_literal: true

class Chronicle
  class Invalidator < ApplicationService
    def initialize(chronicle:, event_uuid:, request_id:, action:, actor: nil, subject: nil, error: nil)
      super()
      @chronicle = chronicle
      @event_uuid = event_uuid
      @request_id = request_id
      @action = action
      @actor = actor
      @subject = subject
      @error = error
    end

    def call
      chronicle.update!(result: "manual_recovery_required")
      Chronicle::FallbackRecorder.call(
        event: "chronicle.audit_incomplete",
        event_uuid: event_uuid,
        request_id: request_id,
        action: action,
        actor: actor,
        subject: subject,
        error: error,
        manual_recovery_required: true,
      )
      chronicle
    end

    private

    attr_reader :chronicle, :event_uuid, :request_id, :action, :actor, :subject, :error
  end
end
