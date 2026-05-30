# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_post_review_statuses
# Database name: app_publisher
#
#  id :bigint           not null, primary key
#
class AppPostReviewStatus < AppPublisherRecord
  include ReferenceRecord

  NOTHING = 1
  ACTIVE = 2
  INACTIVE = 3
  DELETED = 4
  DEFAULTS = [NOTHING, ACTIVE, INACTIVE, DELETED].freeze
  PENDING = NOTHING

  has_many :app_post_reviews, class_name: "AppPostReview", dependent: :restrict_with_error,
                              inverse_of: :app_post_review_status
end
