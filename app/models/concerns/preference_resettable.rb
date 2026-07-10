# typed: false
# frozen_string_literal: true

module PreferenceResettable
  extend ActiveSupport::Concern

  included do
    attr_accessor :confirm_reset

    validate :confirm_reset_accepted, on: :reset
  end

  def require_reset_confirmation(value)
    self.confirm_reset = value
    self
  end

  private

  def confirm_reset_accepted
    return if confirm_reset == "1"

    errors.add(:confirm_reset, :accepted)
  end
end
