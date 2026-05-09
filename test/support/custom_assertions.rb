# typed: false
# frozen_string_literal: true

module CustomAssertions
  def assert_infinity_timestamp_default(record, attribute, msg = nil)
    assert_respond_to record, attribute, "Record should have #{attribute}"
    assert_equal Float::INFINITY, record.public_send(attribute), msg || "Expected #{attribute} to default to infinity"
  end

  def assert_occurrence_lifecycle_defaults(record)
    assert_infinity_timestamp_default(record, :lapses_at)
    assert_infinity_timestamp_default(record, :purge_at)
  end

  def build_occurrence(model_class, attributes = {})
    # Filter out virtual attribute that might be passed by tests but not exist on model
    safe_attributes = attributes.except(:generate_public_id)
    model_class.new(safe_attributes)
  end

  def assert_invalid_attribute(record, attribute, msg = nil)
    record.valid?

    assert_not_empty record.errors[attribute], msg || "Expected error on #{attribute}"
  end

  def assert_public_id_generated(record)
    assert record.save, "Failed to save record: #{record.errors.full_messages}"
    assert_not_nil record.public_id
    assert_not_empty record.public_id
  end

  def assert_public_id_preserved(record, expected_id)
    assert record.save, "Failed to save record: #{record.errors.full_messages}"
    assert_equal expected_id, record.public_id
  end

  def assert_upcases_id(record_or_class)
    record = record_or_class.is_a?(Class) ? record_or_class.new : record_or_class
    record.id = "lower"
    record.valid?

    assert_equal "LOWER", record.id
  end

  def assert_status_association(record_or_class, association_name = nil)
    record = record_or_class.is_a?(Class) ? record_or_class.new : record_or_class
    association_name ||= record.class.name.underscore.sub(/_status$/, "").pluralize

    assert_respond_to record, association_name, "Expected association #{association_name}"
  end
end

class ActiveSupport::TestCase
  include CustomAssertions
end
