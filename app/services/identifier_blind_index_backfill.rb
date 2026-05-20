# typed: false
# frozen_string_literal: true

class IdentifierBlindIndexBackfill
  Result = Data.define(
    :user_emails_updated,
    :user_telephones_updated,
    :staff_emails_updated,
    :staff_telephones_updated,
    :visitor_emails_updated,
    :visitor_telephones_updated,
  )

  def call
    Result.new(
      user_emails_updated: backfill_user_emails,
      user_telephones_updated: backfill_user_telephones,
      staff_emails_updated: backfill_staff_emails,
      staff_telephones_updated: backfill_staff_telephones,
      visitor_emails_updated: backfill_visitor_emails,
      visitor_telephones_updated: backfill_visitor_telephones,
    )
  end

  private

  def backfill_user_emails
    backfill_records(
      model: ClientEmail,
      digest_column: :address_digest,
      bidx_column: :address_bidx,
      identifier_method: :bidx_for_email,
      identifier_method_argument: :address,
    )
  end

  def backfill_user_telephones
    backfill_records(
      model: ClientTelephone,
      digest_column: :number_digest,
      bidx_column: :number_bidx,
      identifier_method: :bidx_for_telephone,
      identifier_method_argument: :number,
    )
  end

  def backfill_staff_emails
    backfill_records(
      model: OperatorEmail,
      digest_column: :address_digest,
      bidx_column: :address_bidx,
      identifier_method: :bidx_for_email,
      identifier_method_argument: :address,
    )
  end

  def backfill_staff_telephones
    backfill_records(
      model: OperatorTelephone,
      digest_column: :number_digest,
      bidx_column: :number_bidx,
      identifier_method: :bidx_for_telephone,
      identifier_method_argument: :number,
    )
  end

  def backfill_visitor_emails
    backfill_records(
      model: VisitorEmail,
      digest_column: :address_digest,
      bidx_column: :address_bidx,
      identifier_method: :bidx_for_email,
      identifier_method_argument: :address,
    )
  end

  def backfill_visitor_telephones
    backfill_records(
      model: VisitorTelephone,
      digest_column: :number_digest,
      bidx_column: :number_bidx,
      identifier_method: :bidx_for_telephone,
      identifier_method_argument: :number,
    )
  end

  def backfill_records(model:, digest_column:, bidx_column:, identifier_method:, identifier_method_argument:)
    return 0 unless model.column_names.include?(digest_column.to_s)

    bidx_column = nil unless model.column_names.include?(bidx_column.to_s)
    updated = 0

    model.find_each(batch_size: 1000) do |record|
      identifier = record.public_send(identifier_method_argument)
      digest = IdentifierBlindIndex.public_send(identifier_method, identifier)
      next if digest.blank?
      next if digest_current?(record, digest_column, bidx_column, digest)

      record.assign_attributes(columns_to_backfill(digest_column, bidx_column, digest))
      record.save!(validate: false)
      updated += 1
    end

    updated
  end

  def digest_current?(record, digest_column, bidx_column, digest)
    record.public_send(digest_column) == digest &&
      (bidx_column.nil? || record.public_send(bidx_column) == digest)
  end

  def columns_to_backfill(digest_column, bidx_column, digest)
    columns = { digest_column => digest }
    columns[bidx_column] = digest if bidx_column
    columns
  end
end
