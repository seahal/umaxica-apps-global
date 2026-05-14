# typed: false
# frozen_string_literal: true

class IdentifierEncryptionReencrypt
  Result = Data.define(
    :user_emails_reencrypted,
    :user_telephones_reencrypted,
    :staff_emails_reencrypted,
    :staff_telephones_reencrypted,
    :visitor_emails_reencrypted,
    :visitor_telephones_reencrypted,
  )

  MODELS = [
    UserEmail,
    UserTelephone,
    OperatorEmail,
    OperatorTelephone,
    VisitorEmail,
    VisitorTelephone,
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
      staff_emails_reencrypted: counts["OperatorEmail"],
      staff_telephones_reencrypted: counts["OperatorTelephone"],
      visitor_emails_reencrypted: counts["VisitorEmail"],
      visitor_telephones_reencrypted: counts["VisitorTelephone"],
    )
  end

  private

  def reencrypt_records(model)
    return 0 unless model.column_names.any?

    updated = 0
    model.in_batches(of: 1000, load: false) do |relation|
      relation.pluck(model.primary_key).each do |record_id|
        begin
          record = model.unscoped.find(record_id)

          model.encrypted_attributes.each do |attr_name|
            value = record.public_send(attr_name)
            record.public_send("#{attr_name}_will_change!")
            record.public_send("#{attr_name}=", value)
          end

          record.save!
          updated += 1
        rescue ActiveRecord::Encryption::Errors::Decryption, OpenSSL::Cipher::CipherError, OpenSSL::Cipher::AuthTagError
          next
        end
      end
    end
    updated
  end
end
