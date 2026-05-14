# typed: false
# frozen_string_literal: true

# Shared account logic for Member and Operator.
# These are the organizational accounts linked to an identity (User or Operator).
module Account
  extend ActiveSupport::Concern

  include ::PublicId

  included do
    validates :status_id, numericality: { only_integer: true }
  end
end
