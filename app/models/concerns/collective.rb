# typed: false
# frozen_string_literal: true

# Shared collective node contract for organization/team/unit/personal hierarchy models.
module Collective
  extend ActiveSupport::Concern

  include ::PublicId

  included do
    validates :name, presence: true, if: -> { has_attribute?(:name) }
    validates :title, presence: true, length: { in: 1..10 },
                      format: { with: /\A[A-Za-z0-9]{1,10}\z/ }, if: -> { has_attribute?(:title) }
  end
end
