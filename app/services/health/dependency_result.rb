# typed: false
# frozen_string_literal: true

module Health
  # Result of a single dependency probe (e.g. one database role check).
  #
  # Aggregated by the check services into the public `dependencies` map on a
  # Health::CheckResult. `public_status` is the only value exposed publicly
  # ("ok"/"failed"); `message` stays internal and must never be serialized into
  # a public response.
  class DependencyResult
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

    def public_status
      ok? ? "ok" : "failed"
    end
  end
end
