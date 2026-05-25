# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: post_review_statuses
# Database name: avatar
#
#  id :bigint           not null, primary key
#

class PostReviewStatus < AppPostReviewStatus
  has_many :post_reviews, class_name: "PostReview", dependent: :restrict_with_error, inverse_of: :post_review_status
end
