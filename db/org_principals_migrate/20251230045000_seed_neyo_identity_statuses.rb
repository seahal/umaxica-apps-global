# frozen_string_literal: true

class SeedNeyoIdentityStatuses < ActiveRecord::Migration[8.2]
  def up
    seed_ids(:user_identity_email_statuses, %w(NEYO))
    seed_ids(:user_identity_telephone_statuses, %w(NEYO))
    seed_ids(:user_identity_statuses, %w(NEYO))
    seed_ids(:staff_identity_statuses, %w(NEYO))
    seed_ids(:staff_identity_email_statuses, %w(NEYO))
    seed_ids(:staff_identity_telephone_statuses, %w(NEYO))
  end

  def down
    # No-op to avoid removing shared reference data
  end

  private

  def seed_ids(table_name, ids)
    return unless table_exists?(table_name)

    has_timestamps = column_exists?(table_name, :created_at)

    ids.each do |_id|
      safety_assured do
        if has_timestamps
        else
        end
      end
    end
  end
end
