# typed: false
# frozen_string_literal: true

class HealthChecksBoot
  def call
    return HealthCheckResult.new(kind: :boot, status: :ok) if Rails.application.initialized?

    HealthCheckResult.new(kind: :boot, status: :starting, message: "Application is starting")
  end
end
