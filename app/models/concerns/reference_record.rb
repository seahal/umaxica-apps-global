# typed: false
# frozen_string_literal: true

module ReferenceRecord
  extend ActiveSupport::Concern

  included do
    self.record_timestamps = false
  end

  class_methods do
    def nothing_id
      self::NOTHING
    end

    def ensure_defaults!
      if defined?(self::DEFAULTS)
        insert_missing_fixed_ids!(self::DEFAULTS)
      else
        ids =
          constants.select do |c|
            next false unless c.to_s == c.to_s.upcase

            val = const_get(c)
            val.is_a?(Integer)
          end.map { |c| const_get(c) }

        insert_missing_fixed_ids!(ids) if ids.any?
      end
    end
  end
end
