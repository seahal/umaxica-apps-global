# typed: false
# frozen_string_literal: true

class BlindIndexUniquenessValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?

    operation = -> { uniqueness_scope(record, attribute, value).exists? }
    duplicate = defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
    return unless duplicate

    record.errors.add(options.fetch(:error_attribute), :taken)
  end

  private

  def uniqueness_scope(record, attribute, value)
    scope = record.class.where(attribute => value).where.not(id: record.id)
    status_column = options[:status_column]
    deleted_status_id = options[:deleted_status_id]
    return scope unless status_column && deleted_status_id

    scope.where.not(status_column => deleted_status_id)
  end
end
