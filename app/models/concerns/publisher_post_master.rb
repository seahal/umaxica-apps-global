# typed: false
# frozen_string_literal: true

module PublisherPostMaster
  extend ActiveSupport::Concern

  included do
    self.primary_key = "id"

    attribute :parent_id, default: 0

    validates :parent_id, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  end

  class_methods do
    def tree_root_parent_value = 0
  end

  def root?
    parent_id.zero?
  end
end
