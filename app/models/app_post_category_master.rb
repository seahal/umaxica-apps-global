# typed: false
# frozen_string_literal: true

class AppPostCategoryMaster < AppPublisherRecord
  self.table_name = "post_category_masters"

  NOTHING = 0
  LEGACY_NOTHING = 1
  DEFAULTS = [NOTHING, LEGACY_NOTHING].freeze

  include PublisherPostMaster

  belongs_to :parent,
             class_name: "AppPostCategoryMaster",
             inverse_of: :children,
             optional: true
  has_many :children,
           class_name: "AppPostCategoryMaster",
           foreign_key: :parent_id,
           inverse_of: :parent,
           dependent: :restrict_with_error
  has_many :post_categories, class_name: "AppPostCategory", dependent: :restrict_with_error, inverse_of: :post_category_master
  has_many :posts, through: :post_categories
end

