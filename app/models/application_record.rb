# typed: false
# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  FIXED_ID_SEED_CACHE = Concurrent::Map.new
  private_constant :FIXED_ID_SEED_CACHE

  # FIXME: i want to remove these lines.
  def self.insert_missing_fixed_ids!(ids)
    return if ids.blank?

    seed_key =
      [
        name,
        connection_db_config&.name || "default",
        ids.uniq.sort.join(","),
      ].join(":")
    return if FIXED_ID_SEED_CACHE[seed_key]

    rows = ids.uniq
    rows.map! { |id| { primary_key => id } }

    operation =
      lambda do
        # Validation-free insert is intentional for fixed-id master rows whose required payload is only the primary key.

        insert_all(
          rows,
          unique_by: [primary_key],
          record_timestamps: record_timestamps,
        )
      end

    raise unless defined?(Prosopite)

    Prosopite.pause(&operation)
    FIXED_ID_SEED_CACHE[seed_key] = true
  end
end
