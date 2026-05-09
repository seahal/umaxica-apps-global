# typed: false
# frozen_string_literal: true

# Shared identity logic for User, Staff, and Customer.
# These are the authenticatable principals that own credentials and sessions.
module Identity
  extend ActiveSupport::Concern

  include ::Accountable
  include ::Withdrawable

  included do
    validates :status_id, numericality: { only_integer: true }
  end

  def login_allowed?
    active? && self.class::LOGIN_BLOCKED_STATUS_IDS.exclude?(status_id)
  end
end
