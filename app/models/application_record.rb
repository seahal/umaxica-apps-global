# typed: false
# frozen_string_literal: true

# TODO: Find out why needs this code
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  FIXED_ID_SEED_CACHE = Concurrent::Map.new
  private_constant :FIXED_ID_SEED_CACHE

  def self.clear_fixed_id_seed_cache!
    FIXED_ID_SEED_CACHE.clear
  end

  # FIXME: i want to remove these lines.
  def self.insert_missing_fixed_ids!(ids)
    return if ids.blank?

    # Gracefully skip if database is not ready or table is missing
    # Use lease_connection for Rails 8 compatibility
    return unless lease_connection.data_source_exists?(table_name)

    fixed_ids = ids.uniq
    seed_key = "#{name}:#{connection_db_config&.name || "default"}:#{fixed_ids.sort.join(",")}"

    present_ids =
      if defined?(Prosopite)
        Prosopite.pause { where(primary_key => fixed_ids).pluck(primary_key) }
      else
        where(primary_key => fixed_ids).pluck(primary_key)
      end
    missing_ids = fixed_ids - present_ids
    return if FIXED_ID_SEED_CACHE[seed_key] && missing_ids.blank?
    return if missing_ids.blank?

    operation =
      lambda do
        now = Time.current
        rows =
          missing_ids.map do |id|
            row = { primary_key => id }
            if record_timestamps
              row["created_at"] = now if column_names.include?("created_at")
              row["updated_at"] = now if column_names.include?("updated_at")
            end
            row
          end

        insert_all(rows)
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid
        # Fallback for concurrent inserts or models without insert_all support
        missing_ids.each do |id|
          where(primary_key => id).first_or_create!
        rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid
          nil
        end
      end

    if defined?(Prosopite)
      Prosopite.pause(&operation)
    else
      operation.call
    end

    FIXED_ID_SEED_CACHE[seed_key] = true
  end
end
