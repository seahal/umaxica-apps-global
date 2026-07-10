# frozen_string_literal: true

require "base64"

class NormalizeStaffPasskeyWebauthnId < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  class StaffPasskey < ActiveRecord::Base
    self.table_name = "staff_passkeys"
  end

  BASE64URL_REGEX = /\A[A-Za-z0-9_-]+\z/

  def up
    return unless table_exists?(:staff_passkeys)

    normalize_webauthn_ids
    remove_duplicate_webauthn_ids

    add_index(
      :staff_passkeys,
      :webauthn_id,
      unique: true,
      algorithm: :concurrently,
      if_not_exists: true,
    )
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def normalize_webauthn_ids
    StaffPasskey.reset_column_information
    StaffPasskey.in_batches(of: 500) do |batch|
      batch.each do |passkey|
        old_value = passkey.webauthn_id.to_s
        next if old_value.blank?

        unless base64_charset?(old_value)
          say("Manual review needed: staff_passkeys id=#{passkey.id} has non-base64 characters", true)
          next
        end

        normalized = normalize_value(old_value)
        next if normalized == old_value

        passkey.update!(webauthn_id: normalized, updated_at: Time.current)
      rescue StandardError => e
        say("Failed to normalize staff_passkeys id=#{passkey.id}: #{e.class}: #{e.message}", true)
      end
    end
  end

  def normalize_value(value)
    decoded = decode_base64url(value)
    return value unless decoded

    decoded.force_encoding("UTF-8")
    return value unless decoded.ascii_only? && decoded.match?(BASE64URL_REGEX)

    decoded
  end

  def decode_base64url(value)
    normalized = value.tr("-_", "+/")
    normalized = normalized.ljust((normalized.length + 3) / 4 * 4, "=")
    Base64.decode64(normalized)
  rescue ArgumentError
    nil
  end

  def base64_charset?(value)
    value.match?(/\A[A-Za-z0-9\-_+=\/]+\z/)
  end

  def remove_duplicate_webauthn_ids
    duplicate_ids =
      StaffPasskey
        .group(:webauthn_id)
        .having("COUNT(*) > 1")
        .pluck(:webauthn_id)

    duplicate_ids.each do |webauthn_id|
      duplicates = StaffPasskey.where(webauthn_id: webauthn_id).order(:created_at, :id).to_a
      next if duplicates.size <= 1

      kept = duplicates.shift
      say("Duplicate staff_passkeys webauthn_id detected; keeping id=#{kept.id}", true)

      duplicates.each do |passkey|
        say("Deleting duplicate staff_passkeys id=#{passkey.id}", true)
        StaffPasskey.where(id: passkey.id).delete_all
      rescue StandardError => e
        say("Failed to delete duplicate staff_passkeys id=#{passkey.id}: #{e.class}: #{e.message}", true)
      end
    end
  end
end
