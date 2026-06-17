# frozen_string_literal: true

require Rails.root.join("lib/observability_redactor").to_s

Sentry.init do |config|
  config.environment = Rails.env
  config.send_default_pii = false
  config.before_send =
    lambda do |event, _hint|
      if event.request
        event.request.url = ObservabilityRedactor.scrub(event.request.url) if event.request.url
        event.request.query_string = ObservabilityRedactor::REDACTED if event.request.query_string
        event.request.env = ObservabilityRedactor.scrub(event.request.env) if event.request.env
        event.request.data = ObservabilityRedactor.scrub(event.request.data) if event.request.data
        event.request.headers = ObservabilityRedactor.scrub(event.request.headers) if event.request.headers
        event.request.cookies = ObservabilityRedactor.scrub(event.request.cookies) if event.request.cookies
      end
      event.extra = ObservabilityRedactor.scrub(event.extra) if event.extra
      event.tags = ObservabilityRedactor.scrub(event.tags) if event.tags
      event.user = ObservabilityRedactor.scrub(event.user) if event.user
      event.breadcrumbs&.each do |breadcrumb|
        breadcrumb.data = ObservabilityRedactor.scrub(breadcrumb.data) if breadcrumb.data
        breadcrumb.message = ObservabilityRedactor.scrub(breadcrumb.message) if breadcrumb.message.is_a?(String)
      end
      event
    end
end
