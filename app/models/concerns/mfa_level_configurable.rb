# typed: false
# frozen_string_literal: true

module MfaLevelConfigurable
  extend ActiveSupport::Concern

  REFERENCE_CLASSES = Concurrent::Map.new

  class_methods do
    def mfa_level_reference(model_class)
      REFERENCE_CLASSES[self] = model_class
    end

    def mfa_level_reference_class
      REFERENCE_CLASSES.fetch(self)
    end
  end

  def mfa_level_enabled=(value)
    enabled = ActiveModel::Type::Boolean.new.cast(value)
    self[:mfa_level_enabled] = enabled if has_attribute?(:mfa_level_enabled)
    self.mfa_level_id = enabled ? mfa_level_full_id : mfa_level_nothing_id if has_attribute?(:mfa_level_id)
  end

  def mfa_level_enabled?
    mfa_level_required?
  end

  def mfa_level_required?
    return legacy_mfa_level_enabled? unless has_attribute?(:mfa_level_id)

    mfa_level_id.to_i != mfa_level_nothing_id || legacy_mfa_level_enabled?
  end

  private

  def legacy_mfa_level_enabled?
    has_attribute?(:mfa_level_enabled) && ActiveModel::Type::Boolean.new.cast(self[:mfa_level_enabled])
  end

  def mfa_level_nothing_id
    self.class.mfa_level_reference_class::NOTHING
  end

  def mfa_level_full_id
    self.class.mfa_level_reference_class::FULL
  end
end
