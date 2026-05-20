# typed: false
# frozen_string_literal: true

# Shared collective node contract for organization/team/unit/personal hierarchy models.
module Collective
  extend ActiveSupport::Concern

  include ::PublicId

  included do
    validates :name, presence: true, if: -> { has_attribute?(:name) }
  end
end
