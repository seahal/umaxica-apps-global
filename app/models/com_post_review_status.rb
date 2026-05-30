# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: com_post_review_statuses
# Database name: com_publisher
#
#  id :bigint           not null, primary key
#
class ComPostReviewStatus < ComPublisherRecord
  include ReferenceRecord

  NOTHING = 1
  ACTIVE = 2
  INACTIVE = 3
  DELETED = 4
  DEFAULTS = [NOTHING, ACTIVE, INACTIVE, DELETED].freeze
  PENDING = NOTHING

  has_many :com_post_reviews, class_name: "ComPostReview", dependent: :restrict_with_error,
                              inverse_of: :com_post_review_status
end
