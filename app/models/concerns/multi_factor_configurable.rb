# typed: false
# frozen_string_literal: true

module MultiFactorConfigurable
  extend ActiveSupport::Concern

  included do
    class_attribute :multi_factor_reference_class, instance_accessor: false
  end

  class_methods do
    def multi_factor_reference(model_class)
      self.multi_factor_reference_class = model_class
    end
  end

  def multi_factor_enabled=(value)
    enabled = ActiveModel::Type::Boolean.new.cast(value)
    self[:multi_factor_enabled] = enabled if has_attribute?(:multi_factor_enabled)
    self.multi_factor_id = enabled ? multi_factor_full_id : multi_factor_nothing_id if has_attribute?(:multi_factor_id)
  end

  def multi_factor_enabled?
    multi_factor_required?
  end

  def multi_factor_required?
    return legacy_multi_factor_enabled? unless has_attribute?(:multi_factor_id)

    multi_factor_id.to_i != multi_factor_nothing_id || legacy_multi_factor_enabled?
  end

  private

  def legacy_multi_factor_enabled?
    has_attribute?(:multi_factor_enabled) && ActiveModel::Type::Boolean.new.cast(self[:multi_factor_enabled])
  end

  def multi_factor_nothing_id
    self.class.multi_factor_reference_class::NOTHING
  end

  def multi_factor_full_id
    self.class.multi_factor_reference_class::FULL
  end
end
