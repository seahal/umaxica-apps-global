# typed: false
# frozen_string_literal: true

class IdentifierBlindIndexBackfill
  Result = Data.define(
    :user_emails_updated,
    :user_telephones_updated,
    :staff_emails_updated,
    :staff_telephones_updated,
  )

  def call
    Result.new(
      user_emails_updated: backfill_user_emails,
      user_telephones_updated: backfill_user_telephones,
      staff_emails_updated: backfill_staff_emails,
      staff_telephones_updated: backfill_staff_telephones,
    )
  end

  private

  def backfill_user_emails
    backfill_records(
      model: UserEmail,
      digest_column: :address_digest,
      bidx_column: :address_bidx,
      identifier_method: :bidx_for_email,
      identifier_method_argument: :address,
    )
  end

  def backfill_user_telephones
    backfill_records(
      model: UserTelephone,
      digest_column: :number_digest,
      bidx_column: :number_bidx,
      identifier_method: :bidx_for_telephone,
      identifier_method_argument: :number,
    )
  end

  def backfill_staff_emails
    backfill_records(
      model: StaffEmail,
      digest_column: :address_digest,
      bidx_column: :address_bidx,
      identifier_method: :bidx_for_email,
      identifier_method_argument: :address,
    )
  end

  def backfill_staff_telephones
    backfill_records(
      model: StaffTelephone,
      digest_column: :number_digest,
      bidx_column: :number_bidx,
      identifier_method: :bidx_for_telephone,
      identifier_method_argument: :number,
    )
  end

  def backfill_records(model:, digest_column:, bidx_column:, identifier_method:, identifier_method_argument:)
    return 0 unless model.column_names.include?(digest_column.to_s)

    updated = 0

    model.find_each(batch_size: 1000) do |record|
      identifier = record.public_send(identifier_method_argument)
      digest = IdentifierBlindIndex.public_send(identifier_method, identifier)
      next if digest.blank?
      next if record.public_send(digest_column) == digest && record.public_send(bidx_column) == digest

      record.update_columns( # rubocop:disable Rails/SkipsModelValidations
        digest_column => digest,
        bidx_column => digest,
      )
      updated += 1
    end

    updated
  end
end
