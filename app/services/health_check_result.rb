# typed: false
# frozen_string_literal: true

class HealthCheckResult
  attr_reader :kind, :status, :message

  def initialize(kind:, status:, message: nil)
    status = status.to_sym
    raise ArgumentError, "unknown health status: #{status}" unless Health::STATUSES.include?(status)

    @kind = kind.to_sym
    @status = status
    @message = message
  end

  def ok?
    status == :ok
  end

  def as_public_json
    { kind: kind.to_s, status: status.to_s }
  end
end
