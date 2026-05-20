# frozen_string_literal: true

class FixMemberPublicIdAndStatusIndexes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  INDEX_NAME = :index_member_identity_statuses_on_lower_id

  def up
    return unless connection.data_source_exists?("members")

    backfill_member_public_ids

    safety_assured do
      connection.execute("ALTER TABLE members ALTER COLUMN public_id SET NOT NULL")
      connection.remove_index(:member_statuses, name: INDEX_NAME, algorithm: :concurrently, if_exists: true)
    end
  end

  def down
    return unless connection.data_source_exists?("members")

    safety_assured do
      unless connection.index_exists?(:member_statuses, "lower((id)::text)", name: INDEX_NAME)
        connection.add_index(
          :member_statuses, "lower((id)::text)", name: INDEX_NAME, unique: true,
                                                 algorithm: :concurrently,
        )
      end
      connection.execute("ALTER TABLE members ALTER COLUMN public_id DROP NOT NULL")
    end
  end

  private

  def backfill_member_public_ids
    connection.select_values(<<~SQL.squish).each do |member_id|
      SELECT id::text
      FROM members
      WHERE public_id IS NULL OR public_id = ''
    SQL
      connection.execute(<<~SQL.squish)
        UPDATE members
        SET public_id = #{connection.quote(generate_public_id)}
        WHERE id = #{connection.quote(member_id)}
      SQL
    end
  end

  def generate_public_id
    loop do
      public_id = Nanoid.generate(size: 21)
      exists = connection.select_value(
        "SELECT 1 FROM members WHERE public_id = #{connection.quote(public_id)} LIMIT 1",
      )
      break public_id unless exists
    end
  end
end
