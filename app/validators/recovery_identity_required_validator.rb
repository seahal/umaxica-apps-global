# typed: false
# frozen_string_literal: true

class RecoveryIdentityRequiredValidator < ActiveModel::Validator
  def validate(record)
    owner = record.public_send(options.fetch(:owner))
    return if owner&.has_verified_recovery_identity?

    record.errors.add(:base, recovery_identity_required_message(record))
  end

  private

  def recovery_identity_required_message(record)
    message = options.fetch(:message)
    return message unless message.is_a?(Symbol)

    record.class.const_get(message)
  end
end
