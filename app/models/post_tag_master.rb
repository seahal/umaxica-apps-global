# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: post_tag_masters
# Database name: app_publisher
#
#  id        :bigint           not null, primary key
#  parent_id :bigint           default(0), not null
#
# Indexes
#
#  index_post_tag_masters_on_parent_id  (parent_id)
#
class PostTagMaster < AppPostTagMaster
  belongs_to :parent,
             class_name: "PostTagMaster",
             inverse_of: :children,
             optional: true
  has_many :children,
           class_name: "PostTagMaster",
           foreign_key: :parent_id,
           inverse_of: :parent,
           dependent: :restrict_with_error
  has_many :post_tags, class_name: "PostTag", dependent: :restrict_with_error, inverse_of: :post_tag_master
  has_many :posts, through: :post_tags
end
