# typed: false
# frozen_string_literal: true

require "test_helper"

class SignRiskEventTest < ActiveSupport::TestCase
  test "creates event with name" do
    event = Sign::Risk::Event.new("login_attempt")

    assert_equal "login_attempt", event.name
    assert_equal({}, event.payload)
    assert_in_delta Time.current, event.occurred_at, 1.second
  end

  test "creates event with payload" do
    event = Sign::Risk::Event.new("login_attempt", payload: { user_id: 123 })

    assert_equal({ user_id: 123 }, event.payload)
  end

  test "creates event with custom occurred_at" do
    time = 1.day.ago
    event = Sign::Risk::Event.new("login_attempt", occurred_at: time)

    assert_equal time, event.occurred_at
  end

  test "to_h returns hash representation" do
    time = Time.current
    event = Sign::Risk::Event.new("login_attempt", payload: { user_id: 123 }, occurred_at: time)

    result = event.to_h

    assert_equal "login_attempt", result[:name]
    assert_equal({ user_id: 123 }, result[:payload])
    assert_equal time.iso8601, result[:occurred_at]
  end
end
