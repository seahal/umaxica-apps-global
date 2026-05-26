# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: post_statuses
# Database name: app_publisher
#
#  id :bigint           not null, primary key
#
class PostStatus < AppPostStatus
  has_many :posts, class_name: "Post", dependent: :restrict_with_error, inverse_of: :post_status
end
