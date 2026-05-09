# typed: false
# frozen_string_literal: true

# Rails 8.1 Structured Logging Configuration
#
# Sets up JSON log formatting and a Rails.event subscriber for structured event output.
# This uses Rails 8.1's native structured logging (config.active_support.structured_logging = true)
# without any external gems.

# Proxy convenience methods to Rails.logger and Rails.event
module Rails
  class << self
    delegate :notice, to: :logger

    def record(name, payload = {})
      event.record(name, payload)
    end
  end
end

# Add NOTICE level to Logger if not present
module ActiveSupport
  class Logger
    unless defined?(NOTICE)
      NOTICE = 1
      def notice(msg); info(msg); end

      def notice?; info?; end
    end
  end

  class BroadcastLogger
    def notice(msg, &); info(msg, &); end

    def notice?; info?; end
  end
end

# JSON Log Formatter - outputs each log line as a single JSON object.
json_formatter =
  proc do |severity, datetime, _progname, msg|
    payload = {
      timestamp: datetime.utc.iso8601(3),
      severity: severity,
      message: msg.is_a?(String) ? msg.strip : msg.inspect,
    }

    "#{payload.to_json}\n"
  end

Rails.application.configure do
  config.log_formatter = json_formatter
end

# Extend Rails.event (ActiveSupport::EventReporter) with convenience methods
ActiveSupport::EventReporter.class_eval do
  # record is an alias for notify as per GEMINI.md / CLAUDE.md
  define_method(:record) do |name, payload = {}|
    notify(name, payload)
  end

  define_method(:notice) do |name, payload = {}|
    notify(name, payload.merge(severity: "NOTICE"))
  end

  define_method(:error) do |name, payload = {}|
    exception = payload[:exception] || payload[:error]

    if exception.is_a?(Exception)
      Rails.error.report(exception, context: payload.except(:exception, :error), handled: true, severity: :error)
    end
    notify(name, payload.merge(severity: "ERROR"))
  end

  define_method(:info) do |name, payload = {}|
    notify(name, payload.merge(severity: "INFO"))
  end

  define_method(:warn) do |name, payload = {}|
    notify(name, payload.merge(severity: "WARN"))
  end

  define_method(:debug) do |name, payload = {}|
    notify(name, payload.merge(severity: "DEBUG"))
  end

  define_method(:fatal) do |name, payload = {}|
    notify(name, payload.merge(severity: "FATAL"))
  end
end

# Structured Event Subscriber - forwards Rails.event emissions to the logger as JSON.
ActiveSupport.on_load(:after_initialize) do
  if defined?(Rails.event) && Rails.event.respond_to?(:subscribe)
    subscriber =
      Class.new do
        define_method(:emit) do |event|
          is_event_obj = event.respond_to?(:payload)
          data = is_event_obj ? event.payload : event

          # If it's a hash from ActiveSupport::EventReporter, it might have internal structure
          if !is_event_obj && data.is_a?(Hash) && data.key?(:name) && data.key?(:payload)
            event_name = data[:name]
            tags = data[:tags]
            context = data[:context]
            source = data[:source_location]
            data = data[:payload]
          else
            event_name = is_event_obj ? event.name : "raw_event"
            tags = event.try(:tags)
            context = event.try(:context)
            source = event.try(:source_location)
          end

          severity = (data[:severity] if data.is_a?(Hash)) || "INFO"

          payload = {
            timestamp: (is_event_obj && event.respond_to?(:time)) ? event.time.utc.iso8601(3) : Time.now.utc.iso8601(3),
            severity: severity,
            event: event_name,
            tags: tags,
            context: context,
            data: data.is_a?(Hash) ? data.except(:severity) : data,
            source: source,
          }

          # Use the appropriate logger method based on severity
          log_method = severity.downcase.to_sym
          if Rails.logger.respond_to?(log_method)
            Rails.logger.public_send(log_method, payload.compact.to_json)
          else
            Rails.logger.info(payload.compact.to_json)
          end
        end
      end

    Rails.event.subscribe(subscriber.new)
    Rails.event.subscribe(JwtAnomalySubscriber.new) if defined?(JwtAnomalySubscriber)
  end

  # Guard product analytics before performant consent.
  # Security, audit, and incident events in PreConsentAllowlist bypass the guard.
  if defined?(ActiveSupport::EventReporter)
    ActiveSupport::EventReporter.prepend(AnalyticsConsentGuard::EventReporterPatch)
  end
end
