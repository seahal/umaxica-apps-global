# typed: false
# frozen_string_literal: true

module Health
  class StatusPolicy
    def self.http_status(status, probe:)
      return 200 if status.to_sym == :starting && probe.to_sym == :live

      case status.to_sym
      when :ok, :degraded_acceptable
        200
      when :unready, :starting
        503
      else
        raise ArgumentError, "unknown health status: #{status}"
      end
    end

    def initialize(acceptable_degraded_kinds: [])
      @acceptable_degraded_kinds = acceptable_degraded_kinds.map(&:to_sym).freeze
    end

    def status_for(results)
      return :ok if results.all?(&:ok?)
      return :degraded_acceptable if degraded_acceptable?(results)

      :unready
    end

    private

    attr_reader :acceptable_degraded_kinds

    def degraded_acceptable?(results)
      failing = results.reject(&:ok?)

      failing.present? && failing.all? do |result|
        result.status == :degraded_acceptable && acceptable_degraded_kinds.include?(result.kind)
      end
    end
  end
end
