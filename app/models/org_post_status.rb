# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: org_post_statuses
# Database name: org_publisher
#
#  id :bigint           not null, primary key
#
class OrgPostStatus < OrgPublisherRecord
  include ReferenceRecord

  NOTHING = 1
  ACTIVE = 2
  INACTIVE = 3
  DELETED = 4
  DEFAULTS = [NOTHING, ACTIVE, INACTIVE, DELETED].freeze

  has_many :org_posts, class_name: "OrgPost", dependent: :restrict_with_error, inverse_of: :org_post_status
end
