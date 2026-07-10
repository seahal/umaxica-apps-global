# typed: false
# frozen_string_literal: true

return if Rails.env.test?

require "opentelemetry/sdk"
require "opentelemetry/exporter/otlp"
require "opentelemetry/instrumentation/action_mailer"
require "opentelemetry/instrumentation/action_pack"
require "opentelemetry/instrumentation/action_view"
require "opentelemetry/instrumentation/active_job"
require "opentelemetry/instrumentation/active_record"
require "opentelemetry/instrumentation/active_support"
require "opentelemetry/instrumentation/concurrent_ruby"
require "opentelemetry/instrumentation/faraday"
require "opentelemetry/instrumentation/net/http"
require "opentelemetry/instrumentation/rack"
require "opentelemetry/instrumentation/redis"
require Rails.root.join("lib/observability_span_scrubber").to_s

OpenTelemetry::SDK.configure do |c|
  c.service_name = "umaxica-apps-jit"
  c.use("OpenTelemetry::Instrumentation::Rack")
  c.use("OpenTelemetry::Instrumentation::ActionPack")
  c.use("OpenTelemetry::Instrumentation::ActionView")
  c.use("OpenTelemetry::Instrumentation::ActiveSupport")
  c.use("OpenTelemetry::Instrumentation::ActiveRecord")
  c.use("OpenTelemetry::Instrumentation::ActionMailer")
  c.use("OpenTelemetry::Instrumentation::ActiveJob")
  c.use("OpenTelemetry::Instrumentation::ConcurrentRuby")
  c.use("OpenTelemetry::Instrumentation::Faraday")
  c.use("OpenTelemetry::Instrumentation::Net::HTTP")
  c.use("OpenTelemetry::Instrumentation::Redis")
  c.add_span_processor(
    Class.new do
      def on_start(*)
      end

      def on_finish(span)
        ObservabilitySpanScrubber.scrub(span)
      end

      def force_flush(*)
        true
      end

      def shutdown(*)
        true
      end
    end.new,
  )
end
