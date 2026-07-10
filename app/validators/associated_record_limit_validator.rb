# typed: false
# frozen_string_literal: true

class AssociatedRecordLimitValidator < ActiveModel::Validator
  def validate(record)
    foreign_key = options.fetch(:foreign_key)
    return if record.public_send(foreign_key).blank?

    limit = limit_for(record)
    return if associated_count(record) < limit

    record.errors.add(
      :base,
      :too_many,
      message: "exceeds maximum #{options.fetch(:record_name)} per #{options.fetch(:owner_name)} (#{limit})",
    )
  end

  private

  def associated_count(record)
    owner = record.public_send(options.fetch(:owner))
    association = options.fetch(:association)

    return owner.public_send(association).count { |associated_record|
      associated_record != record
    } if loaded?(owner, association)

    operation =
      -> {
        record.class.where(options.fetch(:foreign_key) => record.public_send(options.fetch(:foreign_key))).count
      }
    defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
  end

  def loaded?(owner, association)
    owner&.public_send(association)&.loaded?
  end

  def limit_for(record)
    limit = options.fetch(:limit)
    return limit unless limit.is_a?(Symbol)

    record.class.const_get(limit)
  end
end
