# typed: false
# frozen_string_literal: true

# Simple value object for events
class SignRiskEvent
  attr_reader :name, :payload, :occurred_at

  def initialize(name, payload: {}, occurred_at: Time.current)
    @name = name
    @payload = payload
    @occurred_at = occurred_at
  end

  def to_h
    {
      name: name,
      payload: payload,
      occurred_at: occurred_at.iso8601,
    }
  end
end
