# typed: false
# frozen_string_literal: true

module Health
  # Common result object returned by every Health::*Check.call.
  #
  # It is the single source of the public health contract: it owns JSON
  # serialization (`as_public_json`) and the HTTP status decision
  # (`http_status` / `ok?`). Controllers and the snapshot view never hand-roll
  # health JSON; they derive everything from this object.
  #
  # `status` keeps the precise internal vocabulary (`Health::STATUSES`) so the
  # status policy and observability can reason about degradation, while the
  # public payload collapses it to `"ok"` / `"unavailable"`.
  #
  # Holds only primitive data (symbols, strings, hashes, Time) so instances are
  # safe to Marshal into Rails.cache (used by the readiness cache).
  class CheckResult
    attr_reader :check, :status, :dependencies, :surface, :generated_at, :revision

    # check        - probe name: :liveness, :readiness, :startup, :health
    # status       - internal status symbol from Health::STATUSES
    # dependencies - public dependency map, e.g. { "database" => "ok" }, or
    #                nested sub-results for the snapshot
    # surface      - profile surface label (non-sensitive)
    def initialize(check:, status:, surface:, dependencies: {}, generated_at: Time.current,
                   revision: Rails.app.revision.to_s)
      @check = check.to_sym
      @status = status.to_sym
      raise ArgumentError, "unknown health status: #{@status}" unless Health::STATUSES.include?(@status)

      @dependencies = dependencies.freeze
      @surface = surface
      @generated_at = generated_at.utc
      @revision = revision.presence
    end

    def ok?
      http_status == 200
    end

    def http_status
      Health::StatusPolicy.http_status(status, probe: check)
    end

    def as_public_json
      {
        status: ok? ? "ok" : "unavailable",
        check: check.to_s,
        dependencies: dependencies,
        details: details,
      }
    end

    # Non-sensitive diagnostic metadata only. Never exception classes,
    # messages, connection topology, or credentials (see
    # docs/security/observability-boundary.md).
    def details
      details = { surface: surface, generated_at: generated_at.iso8601(3) }
      details[:revision] = revision if revision
      details[:status] = status.to_s unless status == :ok
      details
    end
  end
end
