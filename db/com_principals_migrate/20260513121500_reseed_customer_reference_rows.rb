# frozen_string_literal: true

class ReseedCustomerReferenceRows < ActiveRecord::Migration[8.2]
  REFERENCE_IDS = {
    customer_statuses: [1, 2, 3],
    customer_visibilities: [0, 1, 2, 3],
    customer_email_statuses: [1, 2, 3, 4, 5, 6, 7],
    customer_telephone_statuses: [1, 2, 3, 4, 5, 6, 7],
    customer_secret_statuses: [1, 2, 3, 4, 5, 6],
    customer_secret_kinds: [1, 3, 4],
    customer_passkey_statuses: [1, 2, 3, 4, 5],
  }.freeze

  def up
    safety_assured do
      REFERENCE_IDS.each do |table_name, ids|
        seed_reference_ids(table_name, ids)
      end
    end
  end

  def down
    # No-op: these fixed reference rows may be referenced by customer credentials.
  end

  private

  def seed_reference_ids(table_name, ids)
    return unless table_exists?(table_name)

    ids.each do |id|
      execute(<<~SQL.squish)
        INSERT INTO #{table_name} (id)
        VALUES (#{connection.quote(id)})
        ON CONFLICT (id) DO NOTHING
      SQL
    end

    sequence_name =
      select_value("SELECT pg_get_serial_sequence(#{connection.quote(table_name.to_s)}, 'id')")
    return if sequence_name.blank?

    execute("SELECT setval(#{connection.quote(sequence_name)}, #{ids.max}, true)")
  end
end
