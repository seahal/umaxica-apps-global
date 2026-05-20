# frozen_string_literal: true

class ChangeStaffPublicIdToUppercase16Base32 < ActiveRecord::Migration[8.2]
  PUBLIC_ID_LENGTH = 16
  PUBLIC_ID_ALPHABET = SecureRandom::BASE32_ALPHABET.join.freeze
  VALID_PATTERN = '^[0-9A-FGHJKMNPQRSTVWXYZ]{16}$'

  def up
    backfill_invalid_public_ids

    safety_assured do
      execute(<<~SQL.squish)
        ALTER TABLE staffs
        DROP CONSTRAINT IF EXISTS chk_staffs_public_id_format;
      SQL

      execute(<<~SQL.squish)
        ALTER TABLE staffs
        DROP CONSTRAINT IF EXISTS chk_staffs_public_id_length;
      SQL

      change_column_default(:staffs, :public_id, from: "", to: nil)
      change_column(:staffs, :public_id, :string, limit: PUBLIC_ID_LENGTH, null: false)

      execute(<<~SQL.squish)
        ALTER TABLE staffs
        ADD CONSTRAINT chk_staffs_public_id_length
        CHECK (char_length(public_id) = #{PUBLIC_ID_LENGTH});
      SQL

      execute(<<~SQL.squish)
        ALTER TABLE staffs
        ADD CONSTRAINT chk_staffs_public_id_format
        CHECK (public_id ~ '#{VALID_PATTERN}');
      SQL
    end
  end

  def down
    safety_assured do
      execute(<<~SQL.squish)
        ALTER TABLE staffs
        DROP CONSTRAINT IF EXISTS chk_staffs_public_id_format;
      SQL

      execute(<<~SQL.squish)
        ALTER TABLE staffs
        DROP CONSTRAINT IF EXISTS chk_staffs_public_id_length;
      SQL

      change_column(:staffs, :public_id, :string, limit: 8, null: false)

      execute(<<~SQL.squish)
        ALTER TABLE staffs
        ADD CONSTRAINT chk_staffs_public_id_length
        CHECK (char_length(public_id) = 8);
      SQL

      execute(<<~SQL.squish)
        ALTER TABLE staffs
        ADD CONSTRAINT chk_staffs_public_id_format
        CHECK (public_id ~ '^[abcdefhjklmnpqrtuvwxy23456789]{8}$');
      SQL
    end
  end

  private

  def backfill_invalid_public_ids
    safety_assured do
      invalid_rows = execute(<<~SQL.squish)
        SELECT id, public_id FROM staffs
        WHERE public_id IS NULL
           OR public_id = ''
           OR char_length(public_id) != #{PUBLIC_ID_LENGTH}
           OR public_id !~ '#{VALID_PATTERN}'
      SQL

      return if invalid_rows.ntuples.zero?

      existing_ids = Set.new(
        execute(<<~SQL.squish).pluck("public_id"),
          SELECT public_id FROM staffs
          WHERE public_id IS NOT NULL
            AND public_id != ''
            AND char_length(public_id) = #{PUBLIC_ID_LENGTH}
            AND public_id ~ '#{VALID_PATTERN}'
        SQL
      )

      invalid_rows.each do |row|
        new_id = generate_unique_public_id(existing_ids)
        existing_ids.add(new_id)

        execute(<<~SQL.squish)
          UPDATE staffs SET public_id = '#{new_id}' WHERE id = '#{row["id"]}'
        SQL
      end
    end
  end

  def generate_unique_public_id(existing_ids)
    loop do
      candidate = Array.new(PUBLIC_ID_LENGTH) {
        PUBLIC_ID_ALPHABET[SecureRandom.random_number(PUBLIC_ID_ALPHABET.length)]
      }.join
      return candidate unless existing_ids.include?(candidate)
    end
  end
end
