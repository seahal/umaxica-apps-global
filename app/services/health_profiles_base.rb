# typed: false
# frozen_string_literal: true

class HealthProfilesBase
  attr_reader :cache_key, :surface_label, :record_classes, :status_policy

  def initialize(cache_key:, surface_label:, record_classes:, status_policy: HealthStatusPolicy.new)
    @cache_key = cache_key
    @surface_label = surface_label
    @record_classes = record_classes.freeze
    @status_policy = status_policy
  end

  def readiness_checks
    record_classes.map { |record_class| HealthChecksDatabase.new(record_class: record_class) }
  end
end
