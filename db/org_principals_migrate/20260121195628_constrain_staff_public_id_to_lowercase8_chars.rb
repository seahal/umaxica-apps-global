# frozen_string_literal: true

class ConstrainStaffPublicIdToLowercase8Chars < ActiveRecord::Migration[8.2]
  # Human-readable character set excluding: i, o, 0, 1, s, z, g
  ALLOWED_CHARS = "abcdefhjklmnpqrtuvwxy23456789"
  PUBLIC_ID_LENGTH = 8
  VALID_PATTERN = /\A[abcdefhjklmnpqrtuvwxy23456789]{8}\z/

  def up
    # Step 1: Backfill invalid public_id values (empty, wrong length, or invalid characters)
    # This runs BEFORE column constraints so migration succeeds on dirty data
    backfill_invalid_public_ids

    # Step 2: Remove default (was "" from old migrations)
    safety_assured do
      change_column_default(:staffs, :public_id, from: "", to: nil)
    end

    # Step 3: Change column to limit: 8, null: false
    # Safe now because all rows have valid 8-char public_id
    safety_assured do
      change_column(:staffs, :public_id, :string, limit: 8, null: false)
    end

    # Step 4: Add CHECK constraint for length = 8
    safety_assured do
      execute(<<~SQL.squish)
        ALTER TABLE staffs
        ADD CONSTRAINT chk_staffs_public_id_length
        CHECK (char_length(public_id) = 8);
      SQL
    end

    # Step 5: Add CHECK constraint for allowed characters
    safety_assured do
      execute(<<~SQL.squish)
        ALTER TABLE staffs
        ADD CONSTRAINT chk_staffs_public_id_format
        CHECK (public_id ~ '^[abcdefhjklmnpqrtuvwxy23456789]{8}$');
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

      change_column(:staffs, :public_id, :string, limit: 255, null: true)
      change_column_default(:staffs, :public_id, "")
    end
  end

  private

  # Backfill rows with invalid public_id (empty, wrong length, invalid chars)
  # Uses raw SQL to avoid model dependency and ensure migration stability
  def backfill_invalid_public_ids
    safety_assured do
      # Find all staffs with invalid public_id
      invalid_rows = execute(<<~SQL.squish)
        SELECT id, public_id FROM staffs
        WHERE public_id IS NULL
           OR public_id = ''
           OR char_length(public_id) != #{PUBLIC_ID_LENGTH}
           OR public_id !~ '^[abcdefhjklmnpqrtuvwxy23456789]+$'
      SQL

      return if invalid_rows.ntuples.zero?

      # Collect existing public_ids to avoid collision
      existing_ids = Set.new(
        execute("SELECT public_id FROM staffs WHERE public_id IS NOT NULL AND public_id != ''")
          .pluck("public_id"),
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

  # Generate a unique 8-char public_id not in existing_ids set
  def generate_unique_public_id(existing_ids)
    loop do
      candidate = Array.new(PUBLIC_ID_LENGTH) { ALLOWED_CHARS[SecureRandom.random_number(ALLOWED_CHARS.length)] }.join
      return candidate unless existing_ids.include?(candidate)
    end
  end
end
