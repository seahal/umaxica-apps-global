# frozen_string_literal: true

class CsrfNotificationSubscriber
  FAILURE_EVENT_NAME = "security.csrf.subscriber_failed"
  EVENT_CONFIG = {
    "csrf_token_fallback.action_controller" => ["security.csrf.token_fallback", :info],
    "csrf_request_blocked.action_controller" => ["security.csrf.request_blocked", :warn],
    "csrf_javascript_blocked.action_controller" => ["security.csrf.javascript_blocked", :warn],
  }.freeze
  SEC_FETCH_SITE_VALUES = %w(cross-site same-origin same-site none).freeze

  def emit(event)
    event_name, severity = EVENT_CONFIG.fetch(event.name)
    payload = event.payload

    Rails.logger.public_send(
      severity,
      JitLogEvent.format(
        event_name,
        controller: payload[:controller],
        action: payload[:action],
        sec_fetch_site: normalized_sec_fetch_site(payload[:sec_fetch_site]),
      ),
    )
  rescue StandardError => e
    Rails.logger.error(
      JitLogEvent.format(
        FAILURE_EVENT_NAME,
        error_class: e.class.name,
      ),
    )
  end

  private

  def normalized_sec_fetch_site(value)
    return "missing" if value.nil?
    return value if SEC_FETCH_SITE_VALUES.include?(value)

    "invalid"
  end
end
