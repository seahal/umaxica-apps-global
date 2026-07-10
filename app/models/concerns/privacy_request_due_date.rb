# typed: false
# frozen_string_literal: true

module PrivacyRequestDueDate
  DURATIONS = {
    "jp" => 30.days,
    "us_ca" => 45.days,
    "eu_eea" => 30.days,
    "unknown" => 30.days,
  }.freeze

  def self.due_at(jurisdiction:, received_at:)
    received_at + DURATIONS.fetch(jurisdiction.to_s) { DURATIONS.fetch("unknown") }
  end
end
