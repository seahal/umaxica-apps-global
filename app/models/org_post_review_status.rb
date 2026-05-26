# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: post_review_statuses
# Database name: org_publisher
#
#  id :bigint           not null, primary key
#
class OrgPostReviewStatus < OrgPublisherRecord
  self.table_name = "post_review_statuses"

  include ReferenceRecord

  NOTHING = 1
  ACTIVE = 2
  INACTIVE = 3
  DELETED = 4
  DEFAULTS = [NOTHING, ACTIVE, INACTIVE, DELETED].freeze
  PENDING = NOTHING

  has_many :post_reviews, class_name: "OrgPostReview", dependent: :restrict_with_error, inverse_of: :post_review_status
end
