# typed: false
# frozen_string_literal: true

module Accountable
  extend ActiveSupport::Concern

  # Shared account interface for User, Staff, and Customer.
  def staff?
    raise NotImplementedError, "#{self.class} must implement staff? method"
  end

  def user?
    raise NotImplementedError, "#{self.class} must implement user? method"
  end
end
