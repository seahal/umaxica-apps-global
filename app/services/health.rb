# typed: false
# frozen_string_literal: true

require "timeout"

module Health
  MissingProfileError = Class.new(StandardError)
  DeadlineExceeded = Class.new(StandardError)

  STATUSES = %i(ok degraded_acceptable unready starting).freeze
end
