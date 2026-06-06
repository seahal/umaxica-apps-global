# typed: false
# frozen_string_literal: true

class HealthReport
  CachedProfile = Struct.new(:cache_key, :surface_label, keyword_init: true)

  attr_reader :profile, :probe, :status, :checks, :generated_at, :revision

  def self.live(profile:)
    new(
      profile: profile,
      probe: :live,
      status: Rails.application.initialized? ? :ok : :starting,
      checks: [],
    )
  end

  def initialize(profile:, probe:, status:, checks:, generated_at: Time.current, revision: Rails.app.revision.to_s)
    @profile = profile
    @probe = probe.to_sym
    @status = status.to_sym
    @checks = checks.freeze
    @generated_at = generated_at.utc
    @revision = revision.presence
  end

  def self.aggregate(profile:, probe:, checks:)
    status = profile.status_policy.status_for(checks)

    new(profile: profile, probe: probe, status: status, checks: checks)
  end

  def as_public_json
    {
      status: status.to_s,
      surface: profile.surface_label,
      probe: probe.to_s,
      generated_at: generated_at.iso8601(3),
      revision: revision,
      checks: checks.map(&:as_public_json),
    }.compact
  end

  def marshal_dump
    {
      profile_cache_key: profile.cache_key,
      profile_surface_label: profile.surface_label,
      probe: probe,
      status: status,
      checks: checks,
      generated_at: generated_at,
      revision: revision,
    }
  end

  def marshal_load(payload)
    @profile = CachedProfile.new(
      cache_key: payload.fetch(:profile_cache_key),
      surface_label: payload.fetch(:profile_surface_label),
    )
    @probe = payload.fetch(:probe)
    @status = payload.fetch(:status)
    @checks = payload.fetch(:checks).freeze
    @generated_at = payload.fetch(:generated_at)
    @revision = payload.fetch(:revision)
  end
end
