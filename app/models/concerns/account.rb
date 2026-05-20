# typed: false
# frozen_string_literal: true

# Shared account interface for surface-local account implementations.
module Account
  extend ActiveSupport::Concern

  include ::PublicId

  included do
    validates :status_id, numericality: { only_integer: true }, if: -> { has_attribute?(:status_id) }
  end
end
