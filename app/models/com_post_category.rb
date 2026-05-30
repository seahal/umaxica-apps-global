# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: com_post_categories
# Database name: com_publisher
#
#  id        :bigint           not null, primary key
#  parent_id :bigint           default(0), not null
#
# Indexes
#
#  index_com_post_categories_on_parent_id  (parent_id)
#
class ComPostCategory < ComPublisherRecord
  NOTHING = 0
  LEGACY_NOTHING = 1
  DEFAULTS = [NOTHING, LEGACY_NOTHING].freeze

  include PublisherPostMaster

  belongs_to :parent,
             class_name: "ComPostCategory",
             inverse_of: :children,
             optional: true
  has_many :children,
           class_name: "ComPostCategory",
           foreign_key: :parent_id,
           inverse_of: :parent,
           dependent: :restrict_with_error
  has_many :com_post_categorizations, class_name: "ComPostCategorization", dependent: :restrict_with_error,
                                      inverse_of: :com_post_category
  has_many :com_posts, through: :com_post_categorizations
end
