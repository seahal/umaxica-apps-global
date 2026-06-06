# typed: false
# frozen_string_literal: true

module Health
  module Profiles
    class Base
      attr_reader :cache_key, :surface_label, :record_classes, :status_policy

      def initialize(cache_key:, surface_label:, record_classes:, status_policy: Health::StatusPolicy.new)
        @cache_key = cache_key
        @surface_label = surface_label
        @record_classes = record_classes.freeze
        @status_policy = status_policy
      end

      def readiness_checks
        record_classes.map { |record_class| Health::Checks::Database.new(record_class: record_class) }
      end
    end
  end
end
