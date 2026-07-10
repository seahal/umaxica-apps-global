# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class CspViolationSubscriberTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "emit receives event hash and logs formatted event payload" do
    logged = []
    event = {
      name: CspViolationReportIntake::EVENT_NAME,
      payload: {
        surface: "app",
        host: "app.example.test",
        category: "application",
      },
    }

    Rails.logger.stub(:info, ->(message) { logged << message }) do
      CspViolationSubscriber.new.emit(event)
    end

    parsed = JSON.parse(logged.fetch(0))

    assert_equal CspViolationReportIntake::EVENT_NAME, parsed.fetch("event")
    assert_equal "app", parsed.dig("data", "surface")
    assert_equal "app.example.test", parsed.dig("data", "host")
  end

  test "emit uses hash access not event object access" do
    event = {
      name: CspViolationReportIntake::EVENT_NAME,
      payload: { surface: "org" },
    }

    def event.name = raise(RuntimeError, "object name must not be called")

    def event.payload = raise(RuntimeError, "object payload must not be called")

    Rails.logger.stub(:info, ->(_message) { }) do
      CspViolationSubscriber.new.emit(event)
    end

    assert_equal "org", event.fetch(:payload).fetch(:surface)
  end

  test "logger failures are rescued and logged as subscriber failure" do
    messages = []
    calls = 0
    logger = Object.new

    logger.define_singleton_method(:info) do |_message|
      calls += 1
      raise RuntimeError, "logger unavailable"
    end
    logger.define_singleton_method(:error) do |message|
      messages << message
    end

    Rails.stub(:logger, logger) do
      CspViolationSubscriber.new.emit(
        name: CspViolationReportIntake::EVENT_NAME,
        payload: { surface: "app" },
      )
    end

    parsed = JSON.parse(messages.fetch(0))

    assert_equal 1, calls
    assert_equal CspViolationSubscriber::FAILURE_EVENT_NAME, parsed.fetch("event")
    assert_equal "RuntimeError", parsed.dig("data", "error_class")
    assert_equal "logger unavailable", parsed.dig("data", "error_message")
  end

  test "subscriber does not write to the database" do
    queries = []
    callback =
      lambda do |_name, _start, _finish, _id, payload|
        next if payload[:name] == "SCHEMA"

        queries << payload[:sql]
      end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      Rails.logger.stub(:info, ->(_message) { }) do
        CspViolationSubscriber.new.emit(
          name: CspViolationReportIntake::EVENT_NAME,
          payload: { surface: "app", host: "app.example.test" },
        )
      end
    end

    assert_empty queries.compact
  end

  test "registered Rails event subscriber logs CSP events in process" do
    logged = []

    Rails.logger.stub(:info, ->(message) { logged << message }) do
      Rails.event.notify(
        CspViolationReportIntake::EVENT_NAME,
        surface: "app",
        host: "app.example.test",
        category: "application",
      )
    end

    parsed = JSON.parse(logged.fetch(0))

    assert_equal CspViolationReportIntake::EVENT_NAME, parsed.fetch("event")
    assert_equal "app", parsed.dig("data", "surface")
  end
end
