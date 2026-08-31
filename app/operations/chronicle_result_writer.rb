# typed: false
# frozen_string_literal: true

class ChronicleResultWriter < ChronicleApplicationService
  def initialize(chronicle:, result:, event_uuid:, request_id:, action:, actor: nil, subject: nil, error: nil)
    super()
    @chronicle = chronicle
    @result = result
    @event_uuid = event_uuid
    @request_id = request_id
    @action = action
    @actor = actor
    @subject = subject
    @error = error
  end

  def call
    chronicle.update!(result: result)
    chronicle
  rescue StandardError => e
    ChronicleFallbackRecorder.call(
      event: "chronicle.result_write_failed",
      event_uuid: event_uuid,
      request_id: request_id,
      action: action,
      actor: actor,
      subject: subject,
      error: e,
    )
    raise
  end

  private

  attr_reader :chronicle, :result, :event_uuid, :request_id, :action, :actor, :subject, :error
end
