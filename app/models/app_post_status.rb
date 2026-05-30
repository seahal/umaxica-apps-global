# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_post_statuses
# Database name: app_publisher
#
#  id :bigint           not null, primary key
#
class AppPostStatus < AppPublisherRecord
  include ReferenceRecord

  NOTHING = 1
  ACTIVE = 2
  INACTIVE = 3
  DELETED = 4
  DEFAULTS = [NOTHING, ACTIVE, INACTIVE, DELETED].freeze

  has_many :app_posts, class_name: "AppPost", dependent: :restrict_with_error, inverse_of: :app_post_status
end
