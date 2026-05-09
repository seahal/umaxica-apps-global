# typed: false
# frozen_string_literal: true

class IdentifierEncryptionReencrypt
  Result = Data.define(
    :user_emails_reencrypted,
    :user_telephones_reencrypted,
    :staff_emails_reencrypted,
    :staff_telephones_reencrypted,
    :customer_emails_reencrypted,
    :customer_telephones_reencrypted,
  )

  MODELS = [
    UserEmail,
    UserTelephone,
    StaffEmail,
    StaffTelephone,
    CustomerEmail,
    CustomerTelephone,
  ].freeze

  def initialize(models: MODELS)
    @models = models
  end

  def call
    counts = Hash.new(0)

    @models.each do |model|
      counts[model.name] = reencrypt_records(model)
    end

    Result.new(
      user_emails_reencrypted: counts["UserEmail"],
      user_telephones_reencrypted: counts["UserTelephone"],
      staff_emails_reencrypted: counts["StaffEmail"],
      staff_telephones_reencrypted: counts["StaffTelephone"],
      customer_emails_reencrypted: counts["CustomerEmail"],
      customer_telephones_reencrypted: counts["CustomerTelephone"],
    )
  end

  private

  def reencrypt_records(model)
    return 0 unless model.column_names.any?

    updated = 0
    model.find_each(batch_size: 1000) do |record|
      record.encrypt
      updated += 1
    end
    updated
  end
end
