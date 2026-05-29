# typed: false
# frozen_string_literal: true

class Chronicle
  class FallbackRecorder < ApplicationService
    def initialize(event:, event_uuid:, request_id:, action:, actor: nil, subject: nil, error: nil,
                   manual_recovery_required: false)
      super()
      @event = event
      @event_uuid = event_uuid
      @request_id = request_id
      @action = action
      @actor = actor
      @subject = subject
      @error = error
      @manual_recovery_required = manual_recovery_required
    end

    def call
      Rails.logger.error(Jit::LogEvent.format("chronicle.fallback_record", payload: payload))
    end

    private

    attr_reader :event, :event_uuid, :request_id, :action, :actor, :subject, :error, :manual_recovery_required

    def payload
      Chronicle::Recorder.log_payload(
        event: event,
        event_uuid: event_uuid,
        request_id: request_id,
        action: action,
        actor: actor,
        subject: subject,
        error: error,
        manual_recovery_required: manual_recovery_required,
      )
    end
  end
end
