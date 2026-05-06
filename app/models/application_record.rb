# typed: false
# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # FIXME: i want to remove these lines.
  def self.insert_missing_fixed_ids!(ids)
    return if ids.blank?

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
  end
end
