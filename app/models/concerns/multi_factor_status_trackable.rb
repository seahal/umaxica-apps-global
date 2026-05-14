# typed: false
# frozen_string_literal: true

module MultiFactorStatusTrackable
  extend ActiveSupport::Concern

  class InvalidMultiFactorStatus < StandardError; end

  included do
    class_attribute :multi_factor_status_reference_class, instance_accessor: false
    before_validation :assign_calculated_multi_factor_status, if: :multi_factor_status_placeholder?
    after_create :refresh_multi_factor_status!
  end

  class_methods do
    def multi_factor_status_reference(model_class)
      self.multi_factor_status_reference_class = model_class
    end
  end

  def refresh_multi_factor_status!
    return true unless persisted? && has_attribute?(:multi_factor_status_id)

    next_status_id = calculated_multi_factor_status_id
    return true if multi_factor_status_id.to_i == next_status_id

    update_columns(multi_factor_status_update_attributes(next_status_id))
  end

  def multi_factor_status_active?
    return false unless has_attribute?(:multi_factor_status_id)

    normalized_multi_factor_status_id == multi_factor_status_active_id
  end

  def multi_factor_status_unconfigured?
    return false unless has_attribute?(:multi_factor_status_id)

    normalized_multi_factor_status_id == multi_factor_status_unconfigured_id
  end

  private

  def assign_calculated_multi_factor_status
    self.multi_factor_status_id = calculated_multi_factor_status_id
  end

  def multi_factor_status_placeholder?
    has_attribute?(:multi_factor_status_id) &&
      multi_factor_status_id.to_i == multi_factor_status_nothing_id
  end

  def normalized_multi_factor_status_id
    status_id = multi_factor_status_id.to_i
    return status_id unless status_id == multi_factor_status_nothing_id

    raise InvalidMultiFactorStatus,
          "#{self.class.name}##{id || "new"} has placeholder multi_factor_status_id=#{status_id}"
  end

  def calculated_multi_factor_status_id
    configured_multi_factor_methods.any? ? multi_factor_status_active_id : multi_factor_status_unconfigured_id
  end

  def multi_factor_status_update_attributes(next_status_id)
    attributes = { multi_factor_status_id: next_status_id }
    attributes[:updated_at] = Time.current if has_attribute?(:updated_at)
    attributes
  end

  def configured_multi_factor_methods
    []
  end

  def multi_factor_status_active_id
    self.class.multi_factor_status_reference_class::ACTIVE
  end

  def multi_factor_status_nothing_id
    self.class.multi_factor_status_reference_class::NOTHING
  end

  def multi_factor_status_unconfigured_id
    self.class.multi_factor_status_reference_class::UNCONFIGURED
  end
end
