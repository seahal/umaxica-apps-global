# typed: false
# frozen_string_literal: true

require "openssl"

class IdentifierHmacEmergencyRotation
  Result = Data.define(
    :user_emails_updated,
    :user_telephones_updated,
    :staff_emails_updated,
    :staff_telephones_updated,
    :visitor_emails_updated,
    :visitor_telephones_updated,
    :records_failed,
  )

  IDENTIFIER_TARGETS = [
    {
      model: ClientEmail,
      digest_column: :address_digest,
      identifier_column: :address,
      digest_method: :bidx_for_email,
      result_key: :user_emails_updated,
    },
    {
      model: ClientTelephone,
      digest_column: :number_digest,
      identifier_column: :number,
      digest_method: :bidx_for_telephone,
      result_key: :user_telephones_updated,
    },
    {
      model: OperatorEmail,
      digest_column: :address_digest,
      identifier_column: :address,
      digest_method: :bidx_for_email,
      result_key: :staff_emails_updated,
    },
    {
      model: OperatorTelephone,
      digest_column: :number_digest,
      identifier_column: :number,
      digest_method: :bidx_for_telephone,
      result_key: :staff_telephones_updated,
    },
    {
      model: VisitorEmail,
      digest_column: :address_digest,
      identifier_column: :address,
      digest_method: :bidx_for_email,
      result_key: :visitor_emails_updated,
    },
    {
      model: VisitorTelephone,
      digest_column: :number_digest,
      identifier_column: :number,
      digest_method: :bidx_for_telephone,
      result_key: :visitor_telephones_updated,
    },
  ].freeze

  def initialize(targets: IDENTIFIER_TARGETS)
    @targets = targets
  end

  def call
    counts = Hash.new(0)

    @targets.each do |target|
      result = overwrite_target(target)
      counts[target.fetch(:result_key)] = result.fetch(:updated)
      counts[:records_failed] += result.fetch(:failed)
    end

    Result.new(
      user_emails_updated: counts[:user_emails_updated],
      user_telephones_updated: counts[:user_telephones_updated],
      staff_emails_updated: counts[:staff_emails_updated],
      staff_telephones_updated: counts[:staff_telephones_updated],
      visitor_emails_updated: counts[:visitor_emails_updated],
      visitor_telephones_updated: counts[:visitor_telephones_updated],
      records_failed: counts[:records_failed],
    )
  end

  private

  def overwrite_target(target)
    model = target.fetch(:model)
    return { updated: 0, failed: 0 } unless target_columns_present?(target)

    operation = -> { overwrite_target_records(target, model) }
    defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
  end

  def overwrite_target_records(target, model)
    updated = 0
    failed = 0

    model.in_batches(of: 1000, load: false) do |relation|
      relation.pluck(model.primary_key).each do |record_id|
        if overwrite_record(target, record_id)
          updated += 1
        else
          failed += 1
        end
      end
    end

    { updated: updated, failed: failed }
  end

  def target_columns_present?(target)
    model = target.fetch(:model)
    model.column_names.include?(target.fetch(:digest_column).to_s) &&
      model.column_names.include?(target.fetch(:identifier_column).to_s)
  end

  def overwrite_record(target, record_id)
    model = target.fetch(:model)
    record = model.unscoped.find(record_id)
    identifier = record.public_send(target.fetch(:identifier_column))
    digest = IdentifierBlindIndex.public_send(target.fetch(:digest_method), identifier)
    return true if digest.blank?

    record.assign_attributes(target.fetch(:digest_column) => digest)
    record.save!(validate: false)
    true
  rescue ActiveRecord::Encryption::Errors::Decryption, ActiveRecord::RecordNotFound, OpenSSL::Cipher::CipherError
    false
  end
end
