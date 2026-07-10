# typed: false
# frozen_string_literal: true

class JwtAnomalySubscriber
  def emit(event)
    return unless event.respond_to?(:name) && event.name == "jwt.anomaly.detected"

    payload = event.payload || {}
    code = payload[:reason_code] || payload["reason_code"] || payload[:code] || payload["code"]
    return if code.blank?

    occurrence = JwtOccurrence.find_by(body: code)
    return if occurrence.blank?

    JwtAnomalyEvent.create!(
      jwt_occurrence: occurrence,
      code: code,
      request_host: payload[:request_host].to_s,
      kid: payload[:kid].to_s,
      alg: payload[:alg].to_s,
      typ: payload[:typ].to_s,
      issuer: payload[:iss].to_s,
      jti: payload[:jti].to_s,
      error_class: payload[:error_class].to_s,
      error_message: payload[:error_message].to_s.truncate(1000),
      metadata: build_metadata(payload),
      occurred_at: event.time || Time.current,
    )
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.error(
      JitLogEvent.format(
        "jwt.anomaly.subscriber_failed",
        error_class: e.class.name,
        message: e.message,
      ),
    )
  end

  private

  def build_metadata(payload)
    data = payload.respond_to?(:to_h) ? payload.to_h : {}
    data.except(
      :code,
      :reason_code,
      :request_host,
      :kid,
      :alg,
      :typ,
      :iss,
      :jti,
      :error_class,
      :error_message,
      "code",
      "reason_code",
      "request_host",
      "kid",
      "alg",
      "typ",
      "iss",
      "jti",
      "error_class",
      "error_message",
    )
  end
end
