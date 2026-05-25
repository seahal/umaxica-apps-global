# typed: false
# frozen_string_literal: true

class OrgPostStatus < OrgPublisherRecord
  self.table_name = "post_statuses"

  include ReferenceRecord

  NOTHING = 1
  ACTIVE = 2
  INACTIVE = 3
  DELETED = 4
  DEFAULTS = [NOTHING, ACTIVE, INACTIVE, DELETED].freeze

  has_many :posts, class_name: "OrgPost", dependent: :restrict_with_error, inverse_of: :post_status
end
